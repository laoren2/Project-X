//
//  CompetitionResultView.swift
//  sportsx
//
//  Created by 任杰 on 2025/3/15.
//

import SwiftUI
import MapKit


struct BikeRecordDetailView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel: BikeRecordDetailViewModel
    
    @State private var progressIndex: Int = 0
    @State var isHeartDetail: Bool = false
    @State var isAltitudeDetail: Bool = false
    @State var isSpeedDetail: Bool = false
    
    let formHeight: CGFloat = 80
    
    var overallHeartRateRange: (min: Double?, max: Double?) {
        let mins = viewModel.samplePath.compactMap { $0.heart_rate_min }
        let maxs = viewModel.samplePath.compactMap { $0.heart_rate_max }
        if mins.isEmpty && maxs.isEmpty {
            return (nil, nil)
        }
        let minVal = mins.min()
        let maxVal = maxs.max()
        return (minVal, maxVal)
    }
    
    var overallAltitudeRange: (min: Double, max: Double) {
        let altitudes = viewModel.samplePath.compactMap { $0.altitude_avg }
        let minVal = altitudes.min() ?? 0
        let maxVal = altitudes.max() ?? 0
        return (minVal, maxVal)
    }
    
    var overallSpeedRange: (min: Double, max: Double) {
        let altitudes = viewModel.samplePath.compactMap { $0.speed_avg }
        let minVal = altitudes.min() ?? 0
        let maxVal = altitudes.max() ?? 0
        return (minVal, maxVal)
    }
    
    var heartRateAvg: Double? {
        let validHeartRates = viewModel.basePath.compactMap { $0.heart_rate }
        guard !validHeartRates.isEmpty else { return nil }
        return validHeartRates.reduce(0, +) / Double(validHeartRates.count)
    }
    
    var speedAvg: Double {
        guard !viewModel.basePath.isEmpty else { return 0 }
        
        var totalDistance: Double = 0
        for i in 0..<(viewModel.basePath.count - 1) {
            let p1 = viewModel.basePath[i]
            let p2 = viewModel.basePath[i + 1]
            totalDistance += GeographyTool.haversineDistance(
                lat1: p1.lat, lon1: p1.lon,
                lat2: p2.lat, lon2: p2.lon
            )
        }
        let duration = max(viewModel.basePath.last!.timestamp - viewModel.basePath.first!.timestamp, 0.0001)
        return (totalDistance / duration) * 3.6
    }
    
    var altitudeAvg: Double {
        let altitudes = viewModel.basePath.map { $0.altitude }
        guard !altitudes.isEmpty else { return 0 }
        return altitudes.reduce(0, +) / Double(altitudes.count)
    }
    
#if DEBUG
    @State var isPedalDetail: Bool = false
    var overallPedalCountRange: (min: Double, max: Double) {
        let pedals = viewModel.samplePath.compactMap { $0.pedal_count_avg }
        let minVal = pedals.min() ?? 0
        let maxVal = pedals.max() ?? 0
        return (minVal, maxVal)
    }
    var pedalCountAvg: Double {
        let steps = viewModel.pathData.compactMap { $0.estimate_pedal_count }
        return steps.reduce(0, +) / Double(steps.count)
    }
#endif
    
    var spacingWidth: CGFloat { return ((UIScreen.main.bounds.width - 32) / (1 + CGFloat(viewModel.samplePath.count)) - 2) }
    
    var total_distance: Double {
        guard viewModel.basePath.count > 1 else { return 0 }
        var dist: Double = 0
        for i in 0..<(viewModel.basePath.count - 1) {
            let p1 = viewModel.basePath[i]
            let p2 = viewModel.basePath[i + 1]
            dist += GeographyTool.haversineDistance(
                lat1: p1.lat, lon1: p1.lon,
                lat2: p2.lat, lon2: p2.lon
            )
        }
        return dist
    }
    
    init(recordID: String) {
        _viewModel = StateObject(wrappedValue: BikeRecordDetailViewModel(recordID: recordID))
    }
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 5)
                    .padding(.trailing, 20)
                    .contentShape(Rectangle())
                    .exclusiveTouchTapGesture {
                        adjustNavigationPath()
                    }
                Spacer()
                HStack {
                    Text(LocalizedStringKey(SportName.Bike.name))
                    Text("competition.record.result")
                }
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.vertical, 5)
                        .padding(.trailing, 20)
                        .foregroundColor(.clear)
                }
            }
            .padding(.horizontal)
            
            if let detailInfo = viewModel.recordDetailInfo {
                VStack(spacing: 20) {
                    ZStack(alignment: .bottom) {
                        GradientPathMapView(path: viewModel.basePath, highlightedIndex: progressIndex)
                            .frame(height: 280)
                            .cornerRadius(12)
                        if !viewModel.samplePath.isEmpty {
                            // 当前选中时间段
                            HStack {
                                Text(TimeDisplay.formattedTime(viewModel.samplePath[progressIndex].timestamp_min - viewModel.samplePath[0].timestamp_min))
                                Spacer()
                                Text(TimeDisplay.formattedTime(viewModel.samplePath[progressIndex].timestamp_max - viewModel.samplePath[0].timestamp_min))
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
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            HStack {
                                Text("competition.record.time_and_data")
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(Color.secondText)
                                Spacer()
                            }
                            .padding(.top, 10)
                            // 成绩总览
                            VStack(spacing: 8) {
                                HStack {
                                    Text("competition.track.distance")
                                        .bold()
                                        .foregroundStyle(Color.secondText)
                                    Spacer()
                                    (Text(String(format: "%.2f ", total_distance / 1000.0)) + Text("distance.km"))
                                        .font(.system(.body, design: .rounded, weight: .bold))
                                        .foregroundStyle(Color.white)
                                }
                                HStack {
                                    Text("competition.record.original_time")
                                        .foregroundStyle(Color.secondText)
                                    Spacer()
                                    Text("\(TimeDisplay.formattedTime(detailInfo.originalTime, showFraction: true))")
                                        .font(.system(.body, design: .rounded))
                                        .foregroundStyle(Color.white)
                                }
                                .bold()
                                HStack {
                                    HStack(spacing: 2) {
                                        Text("competition.record.valid_time")
                                            .bold()
                                        Image(systemName: "info.circle")
                                            .font(.subheadline)
                                            .exclusiveTouchTapGesture {
                                                PopupWindowManager.shared.presentPopup(
                                                    title: "competition.record.valid_time",
                                                    message: "competition.record.valid_time.popup.content",
                                                    bottomButtons: [
                                                        .confirm()
                                                    ]
                                                )
                                            }
                                    }
                                    .foregroundStyle(Color.secondText)
                                    Spacer()
                                    Text("\(TimeDisplay.formattedTime(detailInfo.finalTime, showFraction: true))")
                                        .font(.system(.body, design: .rounded, weight: .bold))
                                        .foregroundStyle(Color.white)
                                }
                                HStack {
                                    Text("common.status")
                                        .foregroundStyle(Color.secondText)
                                    Spacer()
                                    if detailInfo.status == .completed {
                                        if detailInfo.isFinishComputed == false {
                                            Text("competition.record.status.computing")
                                                .foregroundColor(.orange)
                                        } else {
                                            Text("competition.record.status.completed")
                                                .foregroundColor(.green)
                                        }
                                    } else {
                                        Text(LocalizedStringKey(detailInfo.status.displayName))
                                            .foregroundStyle(detailInfo.status.backgroundColor)
                                    }
                                }
                                .bold()
                            }
                            Divider()
                                .environment(\.colorScheme, .dark)
                            // 数据统计
                            if !viewModel.samplePath.isEmpty {
                                VStack {
                                    if let rangeMin = overallHeartRateRange.min, let rangeMax = overallHeartRateRange.max {
                                        if isHeartDetail {
                                            VStack {
                                                ZStack(alignment: .center) {
                                                    HStack {
                                                        Text("competition.realtime.heartrate")
                                                        Spacer()
                                                        Text(String(format: "%.0f - %.0f ", rangeMin, rangeMax)) + Text("heartrate.unit")
                                                    }
                                                    .foregroundStyle(Color.red)
                                                    .contentShape(Rectangle())
                                                    .onTapGesture {
                                                        isHeartDetail.toggle()
                                                    }
                                                    if let indexMin = viewModel.samplePath[progressIndex].heart_rate_min,
                                                       let indexMax = viewModel.samplePath[progressIndex].heart_rate_max {
                                                        (Text(String(format: "%.0f - %.0f ", indexMin, indexMax)) + Text("heartrate.unit"))
                                                            .padding(.horizontal)
                                                            .padding(.vertical, 10)
                                                            .font(.caption2)
                                                            .foregroundColor(.white)
                                                            .background(Color.red.opacity(0.8))
                                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                                    } else {
                                                        Text("error.no_data")
                                                            .padding(.horizontal)
                                                            .padding(.vertical, 10)
                                                            .font(.caption2)
                                                            .foregroundColor(.white)
                                                            .background(Color.gray.opacity(0.8))
                                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                                    }
                                                }
                                                //.border(.red)
                                                ZStack {
                                                    HStack(alignment: .center, spacing: spacingWidth) {
                                                        ForEach(viewModel.samplePath.indices, id: \.self) { i in
                                                            // 根据采样数据心率区间的最大值和最小值计算柱状图高度
                                                            if let hrMin = viewModel.samplePath[i].heart_rate_min,
                                                               let hrMax = viewModel.samplePath[i].heart_rate_max {
                                                                let region = rangeMax - rangeMin
                                                                let height = region > 0 ? max(formHeight * (hrMax - hrMin) / region, 4) : 4
                                                                
                                                                // 根据采样数据心率区间的最小值调整Y轴偏移，使柱状图底部对齐
                                                                let offsetY = region > 0 ? (40 - height / 2 - (hrMin - rangeMin) * formHeight / region) : 0
                                                                
                                                                RoundedRectangle(cornerRadius: 1)
                                                                    .fill(i == progressIndex ? Color.red : Color.gray.opacity(0.5))
                                                                    .frame(width: 2, height: height)
                                                                    .offset(y: offsetY)
                                                            } else {
                                                                RoundedRectangle(cornerRadius: 1)
                                                                    .frame(width: 2, height: 2)
                                                                    .hidden()
                                                            }
                                                        }
                                                    }
                                                    GestureOverlayView(pointsCount: viewModel.samplePath.count, progressIndex: $progressIndex)
                                                }
                                                .frame(height: formHeight)
                                                Rectangle()
                                                    .foregroundStyle(Color.gray)
                                                    .frame(height: 1)
                                                HStack {
                                                    Text("00:00")
                                                    Spacer()
                                                    if let EndTime = viewModel.basePath.last?.timestamp, let startTime = viewModel.basePath.first?.timestamp {
                                                        Text("\(TimeDisplay.formattedTime(EndTime - startTime))")
                                                    }
                                                }
                                                .font(.caption)
                                                .foregroundStyle(Color.gray)
                                            }
                                        } else {
                                            HStack {
                                                Text("competition.realtime.heartrate")
                                                Spacer()
                                                if let bpmAvg = heartRateAvg {
                                                    Text("common.average") + Text(String(format: " %.0f ", bpmAvg)) + Text("heartrate.unit")
                                                }
                                            }
                                            .padding()
                                            .foregroundStyle(Color.white)
                                            .background(Color.red.opacity(0.8))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .onTapGesture {
                                                isHeartDetail.toggle()
                                            }
                                        }
                                    }
                                    if isAltitudeDetail {
                                        VStack {
                                            ZStack(alignment: .center) {
                                                HStack {
                                                    Text("competition.track.altitude.2")
                                                    Spacer()
                                                    Text(String(format: "%.0f - %.0f ", overallAltitudeRange.min, overallAltitudeRange.max)) + Text("distance.m")
                                                }
                                                .foregroundStyle(Color.green)
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    isAltitudeDetail.toggle()
                                                }
                                                (Text(String(format: "%.0f ", viewModel.samplePath[progressIndex].altitude_avg)) + Text("distance.m"))
                                                    .padding(.horizontal)
                                                    .padding(.vertical, 10)
                                                    .font(.caption2)
                                                    .foregroundColor(.white)
                                                    .background(Color.green.opacity(0.8))
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                            }
                                            ZStack {
                                                HStack(alignment: .bottom, spacing: spacingWidth) {
                                                    ForEach(viewModel.samplePath.indices, id: \.self) { i in
                                                        let overall = (overallAltitudeRange.max - overallAltitudeRange.min)
                                                        let ratio = overall > 0 ? (viewModel.samplePath[i].altitude_avg - overallAltitudeRange.min) / overall : 1/2
                                                        let height = max(formHeight * ratio, 0) + 4
                                                        
                                                        RoundedRectangle(cornerRadius: 1)
                                                            .fill(i == progressIndex ? Color.green : Color.gray.opacity(0.5))
                                                            .frame(width: 2, height: height)
                                                    }
                                                }
                                                GestureOverlayView(pointsCount: viewModel.samplePath.count, progressIndex: $progressIndex)
                                            }
                                            .frame(height: formHeight)
                                            Rectangle()
                                                .foregroundStyle(Color.gray)
                                                .frame(height: 1)
                                            HStack {
                                                Text("00:00")
                                                Spacer()
                                                if let EndTime = viewModel.basePath.last?.timestamp, let startTime = viewModel.basePath.first?.timestamp {
                                                    Text("\(TimeDisplay.formattedTime(EndTime - startTime))")
                                                }
                                            }
                                            .font(.caption)
                                            .foregroundStyle(Color.gray)
                                        }
                                    } else {
                                        HStack {
                                            Text("competition.track.altitude.2")
                                            Spacer()
                                            Text("common.average") + Text(String(format: " %.0f ", altitudeAvg)) + Text("distance.m")
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
                                                    Text("common.speed")
                                                    Spacer()
                                                    Text(String(format: "%.0f - %.0f ", overallSpeedRange.min, overallSpeedRange.max)) + Text("speed.km/h")
                                                }
                                                .foregroundStyle(Color.orange)
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    isSpeedDetail.toggle()
                                                }
                                                (Text(String(format: "%.0f ", viewModel.samplePath[progressIndex].speed_avg)) + Text("speed.km/h"))
                                                    .padding(.horizontal)
                                                    .padding(.vertical, 10)
                                                    .font(.caption2)
                                                    .foregroundColor(.white)
                                                    .background(Color.orange.opacity(0.8))
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                            }
                                            ZStack {
                                                HStack(alignment: .bottom, spacing: spacingWidth) {
                                                    ForEach(viewModel.samplePath.indices, id: \.self) { i in
                                                        let overall = (overallSpeedRange.max - overallSpeedRange.min)
                                                        let ratio = overall > 0 ? (viewModel.samplePath[i].speed_avg - overallSpeedRange.min) / overall : 1/2
                                                        let height = max(formHeight * ratio, 0) + 4
                                                        
                                                        RoundedRectangle(cornerRadius: 1)
                                                            .fill(i == progressIndex ? Color.orange : Color.gray.opacity(0.5))
                                                            .frame(width: 2, height: height)
                                                    }
                                                }
                                                GestureOverlayView(pointsCount: viewModel.samplePath.count, progressIndex: $progressIndex)
                                            }
                                            .frame(height: formHeight)
                                            Rectangle()
                                                .foregroundStyle(Color.gray)
                                                .frame(height: 1)
                                            HStack {
                                                Text("00:00")
                                                Spacer()
                                                if let EndTime = viewModel.basePath.last?.timestamp, let startTime = viewModel.basePath.first?.timestamp {
                                                    Text("\(TimeDisplay.formattedTime(EndTime - startTime))")
                                                }
                                            }
                                            .font(.caption)
                                            .foregroundStyle(Color.gray)
                                        }
                                    } else {
                                        HStack {
                                            Text("common.speed")
                                            Spacer()
                                            Text("common.average") + Text(String(format: " %.0f ", speedAvg)) + Text("speed.km/h")
                                        }
                                        .padding()
                                        .foregroundStyle(Color.white)
                                        .background(Color.orange.opacity(0.8))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .onTapGesture {
                                            isSpeedDetail.toggle()
                                        }
                                    }
#if DEBUG
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
                                                Text(String(format: "%.0f 次/分", viewModel.samplePath[progressIndex].pedal_count_avg))
                                                    .padding(.horizontal)
                                                    .padding(.vertical, 10)
                                                    .font(.caption2)
                                                    .foregroundColor(.white)
                                                    .background(Color.pink.opacity(0.8))
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                            }
                                            ZStack {
                                                HStack(alignment: .bottom, spacing: spacingWidth) {
                                                    ForEach(viewModel.samplePath.indices, id: \.self) { i in
                                                        let overall = (overallPedalCountRange.max - overallPedalCountRange.min)
                                                        let ratio = overall > 0 ? (viewModel.samplePath[i].pedal_count_avg - overallPedalCountRange.min) / overall : 1/2
                                                        let height = max(formHeight * ratio, 0) + 4
                                                        
                                                        RoundedRectangle(cornerRadius: 1)
                                                            .fill(i == progressIndex ? Color.pink : Color.gray.opacity(0.5))
                                                            .frame(width: 2, height: height)
                                                    }
                                                }
                                                GestureOverlayView(pointsCount: viewModel.samplePath.count, progressIndex: $progressIndex)
                                            }
                                            .frame(height: formHeight)
                                            Rectangle()
                                                .foregroundStyle(Color.gray)
                                                .frame(height: 1)
                                            HStack {
                                                Text("00:00")
                                                Spacer()
                                                if let EndTime = appState.competitionManager.basePathData.last?.timestamp, let startTime = appState.competitionManager.basePathData.first?.timestamp {
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
#endif
                                }
                            }
                            
                            // 我的卡牌收益
                            if !detailInfo.cardBonus.isEmpty {
                                VStack(alignment: .leading, spacing: 20) {
                                    Text("competition.realtime.card.benefit.my")
                                        .font(.title2)
                                        .bold()
                                        .foregroundStyle(Color.secondText)
                                    VStack(spacing: 10) {
                                        ForEach(detailInfo.cardBonus) { bonus in
                                            HStack(spacing: 16) {
                                                MagicCardView(card: bonus.card)
                                                    .frame(width: 60)
                                                VStack(alignment: .leading) {
                                                    Spacer()
                                                    Text(bonus.card.name)
                                                        .font(.headline)
                                                        .bold()
                                                        .foregroundStyle(Color.secondText)
                                                    Spacer()
                                                    (Text("competition.realtime.card.time") + Text(": \(TimeDisplay.formattedTime(bonus.bonusTime, showFraction: true))"))
                                                        .font(.subheadline)
                                                        .foregroundColor(.white)
                                                    Spacer()
                                                }
                                                Spacer()
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.4))
                                    .cornerRadius(12)
                                }
                            }
                            
                            // 其他卡牌收益
                            if !detailInfo.extraCardBonus.isEmpty {
                                VStack(alignment: .leading, spacing: 20) {
                                    Text("competition.realtime.card.benefit.other")
                                        .font(.title2)
                                        .bold()
                                        .foregroundStyle(Color.secondText)
                                    VStack(spacing: 10) {
                                        ForEach(detailInfo.extraCardBonus) { bonus in
                                            HStack(spacing: 16) {
                                                MagicCardView(card: bonus.card)
                                                    .frame(width: 60)
                                                VStack(alignment: .leading) {
                                                    Spacer()
                                                    Text(bonus.card.name)
                                                        .font(.headline)
                                                        .bold()
                                                        .foregroundStyle(Color.secondText)
                                                    Spacer()
                                                    (Text("competition.realtime.card.time") + Text(": \(TimeDisplay.formattedTime(bonus.bonusTime, showFraction: true))"))
                                                        .font(.subheadline)
                                                        .foregroundColor(.white)
                                                    Spacer()
                                                }
                                                Spacer()
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.4))
                                    .cornerRadius(12)
                                }
                            }
                            
                            // team mode 下的队友状态和成绩
                            if !detailInfo.teamMemberScores.isEmpty {
                                VStack(alignment: .leading, spacing: 20) {
                                    Text("competition.team.status")
                                        .font(.title2)
                                        .bold()
                                        .foregroundStyle(Color.secondText)
                                    VStack (spacing: 10) {
                                        ForEach(detailInfo.teamMemberScores) { score in
                                            HStack(spacing: 16) {
                                                HStack(spacing: 10) {
                                                    CachedAsyncImage(
                                                        urlString: score.userInfo.avatarUrl
                                                    )
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 40, height: 40)
                                                    .clipShape(Circle())
                                                    .exclusiveTouchTapGesture {
                                                        appState.navigationManager.append(.userView(id: score.userInfo.userID))
                                                    }
                                                    
                                                    VStack(alignment: .leading, spacing: 3) {
                                                        (score.userInfo.userID == UserManager.shared.user.userID ? Text(LocalizedStringKey("common.me")) : Text(score.userInfo.name))
                                                            .font(.subheadline)
                                                            .foregroundColor(Color.secondText)
                                                    }
                                                }
                                                Spacer()
                                                HStack {
                                                    Text(LocalizedStringKey(score.status.displayName))
                                                        .font(.caption)
                                                        .padding(.vertical, 5)
                                                        .padding(.horizontal, 8)
                                                        .foregroundStyle(Color.secondText)
                                                        .background(score.status.backgroundColor.opacity(0.8))
                                                        .cornerRadius(6)
                                                    if score.status == .completed {
                                                        (Text("competition.record.time") + Text(": \(TimeDisplay.formattedTime(score.finalTime, showFraction: true))"))
                                                            .font(.caption)
                                                            .foregroundColor(.white)
                                                    }
                                                }
                                            }
                                            .padding(.horizontal)
                                            .padding(.vertical, 10)
                                            .background(Color.white.opacity(0.4))
                                            .cornerRadius(12)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 80)
                    }
                }
            } else {
                VStack {
                    Spacer()
                    Text("error.no_data")
                        .foregroundStyle(.white)
                    Spacer()
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture(false)
        .onFirstAppear {
            viewModel.queryRecordDetail()
        }
    }
    
    private func adjustNavigationPath() {
        var cardSelectViewIndex = 1
        var realtimeViewIndex = 1
        if let index = appState.navigationManager.path.firstIndex(where: { $0.string == "competitionCardSelectView" }) {
            cardSelectViewIndex = appState.navigationManager.path.count - index
        }
        if let index = appState.navigationManager.path.firstIndex(where: { $0.string == "competitionRealtimeView" }) {
            realtimeViewIndex = appState.navigationManager.path.count - index
        }
        let lastToRemove = max(1, cardSelectViewIndex, realtimeViewIndex)
        appState.navigationManager.removeLast(lastToRemove)
    }
}

struct RunningRecordDetailView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel: RunningRecordDetailViewModel
    
    @State private var progressIndex: Int = 0
    @State var isHeartDetail: Bool = false
    @State var isAltitudeDetail: Bool = false
    @State var isSpeedDetail: Bool = false
    @State var isStepCadenceDetail: Bool = false
    @State var isPowerDetail: Bool = false
    
    let formHeight: CGFloat = 80
    
    var overallHeartRateRange: (min: Double?, max: Double?) {
        let mins = viewModel.samplePath.compactMap { $0.heart_rate_min }
        let maxs = viewModel.samplePath.compactMap { $0.heart_rate_max }
        if mins.isEmpty && maxs.isEmpty {
            return (nil, nil)
        }
        let minVal = mins.min()
        let maxVal = maxs.max()
        return (minVal, maxVal)
    }
    
    var overallAltitudeRange: (min: Double, max: Double) {
        let altitudes = viewModel.samplePath.compactMap { $0.altitude_avg }
        let minVal = altitudes.min() ?? 0
        let maxVal = altitudes.max() ?? 0
        return (minVal, maxVal)
    }
    
    var overallSpeedRange: (min: Double, max: Double) {
        let altitudes = viewModel.samplePath.compactMap { $0.speed_avg }
        let minVal = altitudes.min() ?? 0
        let maxVal = altitudes.max() ?? 0
        return (minVal, maxVal)
    }
    
    var overallStepCadenceRange: (min: Double?, max: Double?) {
        let steps = viewModel.samplePath.compactMap { $0.step_cadence_avg }
        if steps.isEmpty {
            return (nil, nil)
        }
        let minVal = steps.min() ?? 0
        let maxVal = steps.max() ?? 0
        return (minVal, maxVal)
    }
    
    var overallPowerRange: (min: Double?, max: Double?) {
        let powers = viewModel.samplePath.compactMap { $0.power_avg }
        if powers.isEmpty {
            return (nil, nil)
        }
        let minVal = powers.min() ?? 0
        let maxVal = powers.max() ?? 0
        return (minVal, maxVal)
    }
    
    var heartRateAvg: Double? {
        let validHeartRates = viewModel.basePath.compactMap { $0.heart_rate }
        guard !validHeartRates.isEmpty else { return nil }
        return validHeartRates.reduce(0, +) / Double(validHeartRates.count)
    }
    
    var speedAvg: Double {
        guard !viewModel.basePath.isEmpty else { return 0 }
        
        var totalDistance: Double = 0
        for i in 0..<(viewModel.basePath.count - 1) {
            let p1 = viewModel.basePath[i]
            let p2 = viewModel.basePath[i + 1]
            totalDistance += GeographyTool.haversineDistance(
                lat1: p1.lat, lon1: p1.lon,
                lat2: p2.lat, lon2: p2.lon
            )
        }
        let duration = max(viewModel.basePath.last!.timestamp - viewModel.basePath.first!.timestamp, 0.0001)
        return (totalDistance / duration) * 3.6
    }
    
    var altitudeAvg: Double {
        let altitudes = viewModel.basePath.map { $0.altitude }
        guard !altitudes.isEmpty else { return 0 }
        return altitudes.reduce(0, +) / Double(altitudes.count)
    }
    
    var stepCadenceAvg: Double? {
        let steps = viewModel.pathData.compactMap { $0.step_cadence }
        guard !steps.isEmpty else { return nil }
        return steps.reduce(0, +) / Double(steps.count)
    }
    
    var powerAvg: Double? {
        let powers = viewModel.pathData.compactMap { $0.power }
        guard !powers.isEmpty else { return nil }
        return powers.reduce(0, +) / Double(powers.count)
    }
    
#if DEBUG
    @State var isStepCountDetail: Bool = false
    var overallStepCountRange: (min: Double, max: Double) {
        let steps = viewModel.samplePath.compactMap { $0.estimate_step_count_avg }
        let minVal = steps.min() ?? 0
        let maxVal = steps.max() ?? 0
        return (minVal, maxVal)
    }
    var stepCountAvg: Double {
        let steps = viewModel.pathData.compactMap { $0.estimate_step_count }
        return 20.0 * steps.reduce(0, +) / Double(steps.count)
    }
#endif
    
    var spacingWidth: CGFloat { return ((UIScreen.main.bounds.width - 32) / (1 + CGFloat(viewModel.samplePath.count)) - 2) }
    
    var total_distance: Double {
        guard viewModel.basePath.count > 1 else { return 0 }
        var dist: Double = 0
        for i in 0..<(viewModel.basePath.count - 1) {
            let p1 = viewModel.basePath[i]
            let p2 = viewModel.basePath[i + 1]
            dist += GeographyTool.haversineDistance(
                lat1: p1.lat, lon1: p1.lon,
                lat2: p2.lat, lon2: p2.lon
            )
        }
        return dist
    }
    
    init(recordID: String) {
        _viewModel = StateObject(wrappedValue: RunningRecordDetailViewModel(recordID: recordID))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 5)
                    .padding(.trailing, 20)
                    .contentShape(Rectangle())
                    .exclusiveTouchTapGesture {
                        adjustNavigationPath()
                    }
                Spacer()
                HStack {
                    Text(LocalizedStringKey(SportName.Running.name))
                    Text("competition.record.result")
                }
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.vertical, 5)
                        .padding(.trailing, 20)
                        .foregroundColor(.clear)
                }
            }
            .padding(.horizontal)
            
            if let detailInfo = viewModel.recordDetailInfo {
                VStack(spacing: 20) {
                    ZStack(alignment: .bottom) {
                        GradientPathMapView(path: viewModel.basePath, highlightedIndex: progressIndex)
                            .frame(height: 280)
                            .cornerRadius(12)
                        if !viewModel.samplePath.isEmpty {
                            // 当前选中时间段
                            HStack {
                                Text(TimeDisplay.formattedTime(viewModel.samplePath[progressIndex].timestamp_min - viewModel.samplePath[0].timestamp_min))
                                Spacer()
                                Text(TimeDisplay.formattedTime(viewModel.samplePath[progressIndex].timestamp_max - viewModel.samplePath[0].timestamp_min))
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
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            HStack {
                                Text("competition.record.time_and_data")
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(Color.secondText)
                                Spacer()
                            }
                            .padding(.top, 10)
                            // 成绩总览
                            VStack(spacing: 8) {
                                HStack {
                                    Text("competition.track.distance")
                                        .bold()
                                        .foregroundStyle(Color.secondText)
                                    Spacer()
                                    (Text(String(format: "%.2f ", total_distance / 1000.0)) + Text("distance.km"))
                                        .font(.system(.body, design: .rounded, weight: .bold))
                                        .foregroundStyle(Color.white)
                                }
                                HStack {
                                    Text("competition.record.original_time")
                                        .bold()
                                        .foregroundStyle(Color.secondText)
                                    Spacer()
                                    Text("\(TimeDisplay.formattedTime(detailInfo.originalTime, showFraction: true))")
                                        .font(.system(.body, design: .rounded, weight: .bold))
                                        .foregroundStyle(Color.white)
                                }
                                HStack {
                                    HStack(spacing: 2) {
                                        Text("competition.record.valid_time")
                                            .bold()
                                        Image(systemName: "info.circle")
                                            .font(.subheadline)
                                            .exclusiveTouchTapGesture {
                                                PopupWindowManager.shared.presentPopup(
                                                    title: "competition.record.valid_time",
                                                    message: "competition.record.valid_time.popup.content",
                                                    bottomButtons: [
                                                        .confirm()
                                                    ]
                                                )
                                            }
                                    }
                                    .foregroundStyle(Color.secondText)
                                    Spacer()
                                    Text("\(TimeDisplay.formattedTime(detailInfo.finalTime, showFraction: true))")
                                        .font(.system(.body, design: .rounded, weight: .bold))
                                        .foregroundStyle(Color.white)
                                }
                                HStack {
                                    Text("common.status")
                                        .foregroundStyle(Color.secondText)
                                    Spacer()
                                    if detailInfo.status == .completed {
                                        if detailInfo.isFinishComputed == false {
                                            Text("competition.record.status.computing")
                                                .foregroundColor(.orange)
                                        } else {
                                            Text("competition.record.status.completed")
                                                .foregroundColor(.green)
                                        }
                                    } else {
                                        Text(LocalizedStringKey(detailInfo.status.displayName))
                                            .foregroundStyle(detailInfo.status.backgroundColor)
                                    }
                                }
                                .bold()
                            }
                            Divider()
                                .environment(\.colorScheme, .dark)
                            // 数据统计
                            if !viewModel.samplePath.isEmpty {
                                VStack {
                                    if let rangeMin = overallHeartRateRange.min, let rangeMax = overallHeartRateRange.max {
                                        if isHeartDetail {
                                            VStack {
                                                ZStack(alignment: .center) {
                                                    HStack {
                                                        Text("competition.realtime.heartrate")
                                                        Spacer()
                                                        Text(String(format: "%.0f - %.0f ", rangeMin, rangeMax)) + Text("heartrate.unit")
                                                    }
                                                    .foregroundStyle(Color.red)
                                                    .contentShape(Rectangle())
                                                    .onTapGesture {
                                                        isHeartDetail.toggle()
                                                    }
                                                    if let indexMin = viewModel.samplePath[progressIndex].heart_rate_min,
                                                       let indexMax = viewModel.samplePath[progressIndex].heart_rate_max {
                                                        (Text(String(format: "%.0f - %.0f ", indexMin, indexMax)) + Text("heartrate.unit"))
                                                            .padding(.horizontal)
                                                            .padding(.vertical, 10)
                                                            .font(.caption2)
                                                            .foregroundColor(.white)
                                                            .background(Color.red.opacity(0.8))
                                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                                    } else {
                                                        Text("error.no_data")
                                                            .padding(.horizontal)
                                                            .padding(.vertical, 10)
                                                            .font(.caption2)
                                                            .foregroundColor(.white)
                                                            .background(Color.gray.opacity(0.8))
                                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                                    }
                                                }
                                                //.border(.red)
                                                ZStack {
                                                    HStack(alignment: .center, spacing: spacingWidth) {
                                                        ForEach(viewModel.samplePath.indices, id: \.self) { i in
                                                            // 根据采样数据心率区间的最大值和最小值计算柱状图高度
                                                            if let hrMin = viewModel.samplePath[i].heart_rate_min,
                                                               let hrMax = viewModel.samplePath[i].heart_rate_max {
                                                                let region = rangeMax - rangeMin
                                                                let height = region > 0 ? max(formHeight * (hrMax - hrMin) / region, 4) : 4
                                                                
                                                                // 根据采样数据心率区间的最小值调整Y轴偏移，使柱状图底部对齐
                                                                let offsetY = region > 0 ? (40 - height / 2 - (hrMin - rangeMin) * formHeight / region) : 0
                                                                
                                                                RoundedRectangle(cornerRadius: 1)
                                                                    .fill(i == progressIndex ? Color.red : Color.gray.opacity(0.5))
                                                                    .frame(width: 2, height: height)
                                                                    .offset(y: offsetY)
                                                            } else {
                                                                RoundedRectangle(cornerRadius: 1)
                                                                    .frame(width: 2, height: 2)
                                                                    .hidden()
                                                            }
                                                        }
                                                    }
                                                    GestureOverlayView(pointsCount: viewModel.samplePath.count, progressIndex: $progressIndex)
                                                }
                                                .frame(height: formHeight)
                                                Rectangle()
                                                    .foregroundStyle(Color.gray)
                                                    .frame(height: 1)
                                                HStack {
                                                    Text("00:00")
                                                    Spacer()
                                                    if let EndTime = viewModel.basePath.last?.timestamp, let startTime = viewModel.basePath.first?.timestamp {
                                                        Text("\(TimeDisplay.formattedTime(EndTime - startTime))")
                                                    }
                                                }
                                                .font(.caption)
                                                .foregroundStyle(Color.gray)
                                            }
                                        } else {
                                            HStack {
                                                Text("competition.realtime.heartrate")
                                                Spacer()
                                                if let bpmAvg = heartRateAvg {
                                                    Text("common.average") + Text(String(format: " %.0f ", bpmAvg)) + Text("heartrate.unit")
                                                }
                                            }
                                            .padding()
                                            .foregroundStyle(Color.white)
                                            .background(Color.red.opacity(0.8))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .onTapGesture {
                                                isHeartDetail.toggle()
                                            }
                                        }
                                    }
                                    if isAltitudeDetail {
                                        VStack {
                                            ZStack(alignment: .center) {
                                                HStack {
                                                    Text("competition.track.altitude.2")
                                                    Spacer()
                                                    Text(String(format: "%.0f - %.0f ", overallAltitudeRange.min, overallAltitudeRange.max)) + Text("distance.m")
                                                }
                                                .foregroundStyle(Color.green)
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    isAltitudeDetail.toggle()
                                                }
                                                (Text(String(format: "%.0f ", viewModel.samplePath[progressIndex].altitude_avg)) + Text("distance.m"))
                                                    .padding(.horizontal)
                                                    .padding(.vertical, 10)
                                                    .font(.caption2)
                                                    .foregroundColor(.white)
                                                    .background(Color.green.opacity(0.8))
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                            }
                                            ZStack {
                                                HStack(alignment: .bottom, spacing: spacingWidth) {
                                                    ForEach(viewModel.samplePath.indices, id: \.self) { i in
                                                        let overall = (overallAltitudeRange.max - overallAltitudeRange.min)
                                                        let ratio = overall > 0 ? (viewModel.samplePath[i].altitude_avg - overallAltitudeRange.min) / overall : 1/2
                                                        let height = max(formHeight * ratio, 0) + 4
                                                        
                                                        RoundedRectangle(cornerRadius: 1)
                                                            .fill(i == progressIndex ? Color.green : Color.gray.opacity(0.5))
                                                            .frame(width: 2, height: height)
                                                    }
                                                }
                                                GestureOverlayView(pointsCount: viewModel.samplePath.count, progressIndex: $progressIndex)
                                            }
                                            .frame(height: formHeight)
                                            Rectangle()
                                                .foregroundStyle(Color.gray)
                                                .frame(height: 1)
                                            HStack {
                                                Text("00:00")
                                                Spacer()
                                                if let EndTime = viewModel.basePath.last?.timestamp, let startTime = viewModel.basePath.first?.timestamp {
                                                    Text("\(TimeDisplay.formattedTime(EndTime - startTime))")
                                                }
                                            }
                                            .font(.caption)
                                            .foregroundStyle(Color.gray)
                                        }
                                    } else {
                                        HStack {
                                            Text("competition.track.altitude.2")
                                            Spacer()
                                            Text("common.average") + Text(String(format: " %.0f ", altitudeAvg)) + Text("distance.m")
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
                                                    Text("common.speed")
                                                    Spacer()
                                                    Text(SpeedHelper.paceString(from: overallSpeedRange.min)) + Text(" - ") + Text(SpeedHelper.paceString(from: overallSpeedRange.max)) + Text("/") + Text("distance.km")
                                                }
                                                .foregroundStyle(Color.orange)
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    isSpeedDetail.toggle()
                                                }
                                                (Text(SpeedHelper.paceString(from: viewModel.samplePath[progressIndex].speed_avg)) + Text("/") + Text("distance.km"))
                                                    .padding(.horizontal)
                                                    .padding(.vertical, 10)
                                                    .font(.caption2)
                                                    .foregroundColor(.white)
                                                    .background(Color.orange.opacity(0.8))
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                            }
                                            ZStack {
                                                HStack(alignment: .bottom, spacing: spacingWidth) {
                                                    ForEach(viewModel.samplePath.indices, id: \.self) { i in
                                                        let overall = (overallSpeedRange.max - overallSpeedRange.min)
                                                        let ratio = overall > 0 ? (viewModel.samplePath[i].speed_avg - overallSpeedRange.min) / overall : 1/2
                                                        let height = max(formHeight * ratio, 0) + 4
                                                        
                                                        RoundedRectangle(cornerRadius: 1)
                                                            .fill(i == progressIndex ? Color.orange : Color.gray.opacity(0.5))
                                                            .frame(width: 2, height: height)
                                                    }
                                                }
                                                GestureOverlayView(pointsCount: viewModel.samplePath.count, progressIndex: $progressIndex)
                                            }
                                            .frame(height: formHeight)
                                            Rectangle()
                                                .foregroundStyle(Color.gray)
                                                .frame(height: 1)
                                            HStack {
                                                Text("00:00")
                                                Spacer()
                                                if let EndTime = viewModel.basePath.last?.timestamp, let startTime = viewModel.basePath.first?.timestamp {
                                                    Text("\(TimeDisplay.formattedTime(EndTime - startTime))")
                                                }
                                            }
                                            .font(.caption)
                                            .foregroundStyle(Color.gray)
                                        }
                                    } else {
                                        HStack {
                                            Text("common.speed")
                                            Spacer()
                                            Text("common.average") + Text(SpeedHelper.paceString(from: speedAvg)) + Text("/") + Text("distance.km")
                                        }
                                        .padding()
                                        .foregroundStyle(Color.white)
                                        .background(Color.orange.opacity(0.8))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .onTapGesture {
                                            isSpeedDetail.toggle()
                                        }
                                    }
                                    
                                    if let rangeMin = overallStepCadenceRange.min, let rangeMax = overallStepCadenceRange.max {
                                        if isStepCadenceDetail {
                                            VStack {
                                                ZStack(alignment: .center) {
                                                    HStack {
                                                        Text("competition.result.stepcadence")
                                                        Spacer()
                                                        (Text(String(format: "%.0f - %.0f ", rangeMin, rangeMax)) + Text("stepCadence.unit"))
                                                    }
                                                    .foregroundStyle(Color.pink)
                                                    .contentShape(Rectangle())
                                                    .onTapGesture {
                                                        isStepCadenceDetail.toggle()
                                                    }
                                                    if let avg = viewModel.samplePath[progressIndex].step_cadence_avg {
                                                        (Text(String(format: "%.0f ", avg)) + Text("stepCadence.unit"))
                                                            .padding(.horizontal)
                                                            .padding(.vertical, 10)
                                                            .font(.caption2)
                                                            .foregroundColor(.white)
                                                            .background(Color.pink.opacity(0.8))
                                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                                    } else {
                                                        Text("error.no_data")
                                                            .padding(.horizontal)
                                                            .padding(.vertical, 10)
                                                            .font(.caption2)
                                                            .foregroundColor(.white)
                                                            .background(Color.gray.opacity(0.8))
                                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                                    }
                                                }
                                                ZStack {
                                                    HStack(alignment: .bottom, spacing: spacingWidth) {
                                                        ForEach(viewModel.samplePath.indices, id: \.self) { i in
                                                            if let step_avg = viewModel.samplePath[i].step_cadence_avg {
                                                                let overall = rangeMax - rangeMin
                                                                let ratio = overall > 0 ? (step_avg - rangeMin) / overall : 1/2
                                                                let height = max(formHeight * ratio, 0) + 4
                                                                
                                                                RoundedRectangle(cornerRadius: 1)
                                                                    .fill(i == progressIndex ? Color.pink : Color.gray.opacity(0.5))
                                                                    .frame(width: 2, height: height)
                                                            } else {
                                                                RoundedRectangle(cornerRadius: 1)
                                                                    .frame(width: 2, height: 2)
                                                                    .hidden()
                                                            }
                                                        }
                                                    }
                                                    GestureOverlayView(pointsCount: viewModel.samplePath.count, progressIndex: $progressIndex)
                                                }
                                                .frame(height: formHeight)
                                                Rectangle()
                                                    .foregroundStyle(Color.gray)
                                                    .frame(height: 1)
                                                HStack {
                                                    Text("00:00")
                                                    Spacer()
                                                    if let EndTime = viewModel.basePath.last?.timestamp, let startTime = viewModel.basePath.first?.timestamp {
                                                        Text("\(TimeDisplay.formattedTime(EndTime - startTime))")
                                                    }
                                                }
                                                .font(.caption)
                                                .foregroundStyle(Color.gray)
                                            }
                                        } else {
                                            HStack {
                                                Text("competition.result.stepcadence")
                                                Spacer()
                                                if let stepAvg = stepCadenceAvg {
                                                    Text("common.average") + Text(String(format: " %.0f ", stepAvg)) + Text("stepCadence.unit")
                                                }
                                            }
                                            .padding()
                                            .foregroundStyle(Color.white)
                                            .background(Color.pink.opacity(0.8))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .onTapGesture {
                                                isStepCadenceDetail.toggle()
                                            }
                                        }
                                    }
                                    if let rangeMin = overallPowerRange.min, let rangeMax = overallPowerRange.max {
                                        if isPowerDetail {
                                            VStack {
                                                ZStack(alignment: .center) {
                                                    HStack {
                                                        Text("competition.realtime.power")
                                                        Spacer()
                                                        (Text(String(format: "%.0f - %.0f ", rangeMin, rangeMax)) + Text("power.unit"))
                                                    }
                                                    .foregroundStyle(Color.blue)
                                                    .contentShape(Rectangle())
                                                    .onTapGesture {
                                                        isPowerDetail.toggle()
                                                    }
                                                    if let avg = viewModel.samplePath[progressIndex].power_avg {
                                                        (Text(String(format: "%.0f ", avg)) + Text("power.unit"))
                                                            .padding(.horizontal)
                                                            .padding(.vertical, 10)
                                                            .font(.caption2)
                                                            .foregroundColor(.white)
                                                            .background(Color.blue.opacity(0.8))
                                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                                    } else {
                                                        Text("error.no_data")
                                                            .padding(.horizontal)
                                                            .padding(.vertical, 10)
                                                            .font(.caption2)
                                                            .foregroundColor(.white)
                                                            .background(Color.gray.opacity(0.8))
                                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                                    }
                                                }
                                                ZStack {
                                                    HStack(alignment: .bottom, spacing: spacingWidth) {
                                                        ForEach(viewModel.samplePath.indices, id: \.self) { i in
                                                            if let power_avg = viewModel.samplePath[i].power_avg {
                                                                let overall = rangeMax - rangeMin
                                                                let ratio = overall > 0 ? (power_avg - rangeMin) / overall : 1/2
                                                                let height = max(formHeight * ratio, 0) + 4
                                                                
                                                                RoundedRectangle(cornerRadius: 1)
                                                                    .fill(i == progressIndex ? Color.blue : Color.gray.opacity(0.5))
                                                                    .frame(width: 2, height: height)
                                                            } else {
                                                                RoundedRectangle(cornerRadius: 1)
                                                                    .frame(width: 2, height: 2)
                                                                    .hidden()
                                                            }
                                                        }
                                                    }
                                                    GestureOverlayView(pointsCount: viewModel.samplePath.count, progressIndex: $progressIndex)
                                                }
                                                .frame(height: formHeight)
                                                Rectangle()
                                                    .foregroundStyle(Color.gray)
                                                    .frame(height: 1)
                                                HStack {
                                                    Text("00:00")
                                                    Spacer()
                                                    if let EndTime = viewModel.basePath.last?.timestamp, let startTime = viewModel.basePath.first?.timestamp {
                                                        Text("\(TimeDisplay.formattedTime(EndTime - startTime))")
                                                    }
                                                }
                                                .font(.caption)
                                                .foregroundStyle(Color.gray)
                                            }
                                        } else {
                                            HStack {
                                                Text("competition.realtime.power")
                                                Spacer()
                                                if let powerAvg = powerAvg {
                                                    Text("common.average") + Text(String(format: " %.0f ", powerAvg)) + Text("power.unit")
                                                }
                                            }
                                            .padding()
                                            .foregroundStyle(Color.white)
                                            .background(Color.blue.opacity(0.8))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .onTapGesture {
                                                isPowerDetail.toggle()
                                            }
                                        }
                                    }
#if DEBUG
                                    if isStepCountDetail {
                                        VStack {
                                            ZStack(alignment: .center) {
                                                HStack {
                                                    Text("测试步频")
                                                    Spacer()
                                                    Text(String(format: "%.0f - %.0f 步/分", overallStepCountRange.min, overallStepCountRange.max))
                                                }
                                                .foregroundStyle(Color.pink)
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    isStepCountDetail.toggle()
                                                }
                                                Text(String(format: "%.0f 步/分", viewModel.samplePath[progressIndex].estimate_step_count_avg))
                                                    .padding(.horizontal)
                                                    .padding(.vertical, 10)
                                                    .font(.caption2)
                                                    .foregroundColor(.white)
                                                    .background(Color.pink.opacity(0.8))
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                            }
                                            ZStack {
                                                HStack(alignment: .bottom, spacing: spacingWidth) {
                                                    ForEach(viewModel.samplePath.indices, id: \.self) { i in
                                                        let overall = (overallStepCountRange.max - overallStepCountRange.min)
                                                        let ratio = overall > 0 ? (viewModel.samplePath[i].estimate_step_count_avg - overallStepCountRange.min) / overall : 1/2
                                                        let height = max(formHeight * ratio, 0) + 4
                                                        
                                                        RoundedRectangle(cornerRadius: 1)
                                                            .fill(i == progressIndex ? Color.pink : Color.gray.opacity(0.5))
                                                            .frame(width: 2, height: height)
                                                    }
                                                }
                                                GestureOverlayView(pointsCount: viewModel.samplePath.count, progressIndex: $progressIndex)
                                            }
                                            .frame(height: formHeight)
                                            Rectangle()
                                                .foregroundStyle(Color.gray)
                                                .frame(height: 1)
                                            HStack {
                                                Text("00:00")
                                                Spacer()
                                                if let EndTime = viewModel.basePath.last?.timestamp, let startTime = viewModel.basePath.first?.timestamp {
                                                    Text("\(TimeDisplay.formattedTime(EndTime - startTime))")
                                                }
                                            }
                                            .font(.caption)
                                            .foregroundStyle(Color.gray)
                                        }
                                    } else {
                                        HStack {
                                            Text("测试步频")
                                            Spacer()
                                            Text(String(format: "平均 %.0f 步/分", stepCountAvg))
                                        }
                                        .padding()
                                        .foregroundStyle(Color.white)
                                        .background(Color.pink.opacity(0.8))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .onTapGesture {
                                            isStepCountDetail.toggle()
                                        }
                                    }
#endif
                                }
                            }
                            
                            // 我的卡牌收益
                            if !detailInfo.cardBonus.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("competition.realtime.card.benefit.my")
                                        .font(.title2)
                                        .bold()
                                        .foregroundStyle(Color.secondText)
                                    VStack(spacing: 10) {
                                        ForEach(detailInfo.cardBonus) { bonus in
                                            HStack(spacing: 16) {
                                                MagicCardView(card: bonus.card)
                                                    .frame(width: 60)
                                                VStack(alignment: .leading) {
                                                    Spacer()
                                                    Text(bonus.card.name)
                                                        .font(.headline)
                                                        .bold()
                                                        .foregroundStyle(Color.secondText)
                                                    Spacer()
                                                    (Text("competition.realtime.card.time") + Text(": \(TimeDisplay.formattedTime(bonus.bonusTime, showFraction: true))"))
                                                        .font(.subheadline)
                                                        .foregroundColor(.white)
                                                    Spacer()
                                                }
                                                Spacer()
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.4))
                                    .cornerRadius(12)
                                }
                            }
                            
                            // 其他卡牌收益
                            if !detailInfo.extraCardBonus.isEmpty {
                                VStack(alignment: .leading, spacing: 20) {
                                    Text("competition.realtime.card.benefit.other")
                                        .font(.title2)
                                        .bold()
                                        .foregroundStyle(Color.secondText)
                                    VStack(spacing: 10) {
                                        ForEach(detailInfo.extraCardBonus) { bonus in
                                            HStack(spacing: 16) {
                                                MagicCardView(card: bonus.card)
                                                    .frame(width: 60)
                                                VStack(alignment: .leading) {
                                                    Spacer()
                                                    Text(bonus.card.name)
                                                        .font(.headline)
                                                        .bold()
                                                        .foregroundStyle(Color.secondText)
                                                    Spacer()
                                                    (Text("competition.realtime.card.time") + Text(": \(TimeDisplay.formattedTime(bonus.bonusTime, showFraction: true))"))
                                                        .font(.subheadline)
                                                        .foregroundColor(.white)
                                                    Spacer()
                                                }
                                                Spacer()
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.4))
                                    .cornerRadius(12)
                                }
                            }
                            
                            // team mode 下的队友状态和成绩
                            if !detailInfo.teamMemberScores.isEmpty {
                                VStack(alignment: .leading, spacing: 20) {
                                    Text("competition.team.status")
                                        .font(.title2)
                                        .bold()
                                        .foregroundStyle(Color.secondText)
                                    VStack (spacing: 10) {
                                        ForEach(detailInfo.teamMemberScores) { score in
                                            HStack(spacing: 16) {
                                                HStack(spacing: 10) {
                                                    CachedAsyncImage(
                                                        urlString: score.userInfo.avatarUrl
                                                    )
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 40, height: 40)
                                                    .clipShape(Circle())
                                                    .exclusiveTouchTapGesture {
                                                        appState.navigationManager.append(.userView(id: score.userInfo.userID))
                                                    }
                                                    
                                                    VStack(alignment: .leading, spacing: 3) {
                                                        (score.userInfo.userID == UserManager.shared.user.userID ? Text(LocalizedStringKey("common.me")) : Text(score.userInfo.name))
                                                            .font(.subheadline)
                                                            .foregroundColor(Color.secondText)
                                                    }
                                                }
                                                Spacer()
                                                HStack {
                                                    Text(LocalizedStringKey(score.status.displayName))
                                                        .font(.caption)
                                                        .padding(.vertical, 5)
                                                        .padding(.horizontal, 8)
                                                        .foregroundStyle(Color.secondText)
                                                        .background(score.status.backgroundColor.opacity(0.8))
                                                        .cornerRadius(6)
                                                    (Text("competition.record.time") + Text(": \(TimeDisplay.formattedTime(score.finalTime, showFraction: true))"))
                                                        .font(.caption)
                                                        .foregroundColor(.white)
                                                }
                                            }
                                            .padding(.horizontal)
                                            .padding(.vertical, 10)
                                            .background(Color.white.opacity(0.4))
                                            .cornerRadius(12)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 80)
                    }
                }
            } else {
                VStack {
                    Spacer()
                    Text("error.no_data")
                        .foregroundStyle(.white)
                    Spacer()
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture(false)
        .onFirstAppear {
            viewModel.queryRecordDetail()
        }
    }
    
    private func adjustNavigationPath() {
        var cardSelectViewIndex = 1
        var realtimeViewIndex = 1
        if let index = appState.navigationManager.path.firstIndex(where: { $0.string == "competitionCardSelectView" }) {
            cardSelectViewIndex = appState.navigationManager.path.count - index
        }
        if let index = appState.navigationManager.path.firstIndex(where: { $0.string == "competitionRealtimeView" }) {
            realtimeViewIndex = appState.navigationManager.path.count - index
        }
        let lastToRemove = max(1, cardSelectViewIndex, realtimeViewIndex)
        appState.navigationManager.removeLast(lastToRemove)
    }
}

struct GestureOverlayView: View {
    @State private var lastHapticTime: TimeInterval = 0
    let pointsCount: Int
    @Binding var progressIndex: Int
    let formWidth: CGFloat = UIScreen.main.bounds.width - 32

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        // 点击时手势位移太大会被忽略
                        if abs(value.location.x - value.startLocation.x) > 5 ||
                           abs(value.location.y - value.startLocation.y) > 5 {
                            return
                        }

                        updateProgress(for: value.location.x)
                    }
            )
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onChanged { value in
                        updateProgress(for: value.location.x)
                    }
                    .onEnded { _ in }
            )
    }

    private func updateProgress(for x: CGFloat) {
        guard pointsCount > 0, formWidth > 0 else { return }

        var ratio = x / formWidth
        ratio = min(max(ratio, 0), 0.999)
        let idx = min(Int(ratio * CGFloat(pointsCount)), pointsCount - 1)
        if idx != progressIndex {
            progressIndex = idx
            // 节流：每 0.1s 最多触发一次震动
            let now = Date().timeIntervalSince1970
            if now - lastHapticTime > 0.1 {
                lastHapticTime = now
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }
}

#Preview {
    let appState = AppState.shared
    return BikeRecordDetailView(recordID: "test")
        .environmentObject(appState)
}
