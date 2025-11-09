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
    
    var spacingWidth: CGFloat { return ((UIScreen.main.bounds.width - 32) / (1 + CGFloat(viewModel.samplePath.count)) - 2) }
    
    init(recordID: String) {
        _viewModel = StateObject(wrappedValue: BikeRecordDetailViewModel(recordID: recordID))
    }
    
    var body: some View {
        VStack {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    adjustNavigationPath()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                Spacer()
                Text("bike比赛结算")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
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
                    ScrollView(showsIndicators: false) {
                        HStack {
                            Text("成绩与数据")
                                .font(.title2)
                                .bold()
                                .foregroundStyle(Color.secondText)
                            Spacer()
                        }
                        .padding(.bottom, 20)
                        // 成绩总览
                        VStack(spacing: 8) {
                            HStack {
                                Text("原始时间:")
                                    .bold()
                                    .foregroundStyle(Color.secondText)
                                Spacer()
                                Text("\(detailInfo.originalTime)")
                                    .font(.system(.body, design: .rounded))
                                    .bold()
                                    .foregroundStyle(Color.white)
                            }
                            HStack {
                                Text("有效时间:")
                                    .bold()
                                    .foregroundStyle(Color.secondText)
                                Spacer()
                                Text("\(detailInfo.finalTime)")
                                    .font(.system(.body, design: .rounded))
                                    .bold()
                                    .foregroundStyle(Color.white)
                            }
                            HStack {
                                Text("状态:")
                                    .bold()
                                    .foregroundStyle(Color.secondText)
                                Spacer()
                                if detailInfo.status == .completed {
                                    if detailInfo.isFinishComputed == false {
                                        Text("计算中...")
                                            .foregroundColor(.orange)
                                            .bold()
                                    } else {
                                        Text("已完成")
                                            .foregroundColor(.green)
                                            .bold()
                                    }
                                } else if detailInfo.status == .expired {
                                    Text("数据异常")
                                        .foregroundColor(.red)
                                        .bold()
                                } else if detailInfo.status == .invalid {
                                    Text("数据校验失败")
                                        .foregroundColor(.red)
                                        .bold()
                                }
                            }
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
                                                    Text("心率")
                                                    Spacer()
                                                    Text(String(format: "%.0f - %.0f 次/分", rangeMin, rangeMax))
                                                }
                                                .foregroundStyle(Color.red)
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    isHeartDetail.toggle()
                                                }
                                                if let indexMin = viewModel.samplePath[progressIndex].heart_rate_min,
                                                   let indexMax = viewModel.samplePath[progressIndex].heart_rate_max {
                                                    Text(String(format: "%.0f - %.0f 次/分", indexMin, indexMax))
                                                        .padding(.horizontal)
                                                        .padding(.vertical, 10)
                                                        .font(.caption2)
                                                        .foregroundColor(.white)
                                                        .background(Color.red.opacity(0.8))
                                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                                } else {
                                                    Text("无数据")
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
                                            Text("心率")
                                            Spacer()
                                            if let bpmAvg = heartRateAvg {
                                                Text(String(format: "平均 %.0f 次/分", bpmAvg))
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
                                                Text("海拔")
                                                Spacer()
                                                Text(String(format: "%.0f - %.0f 米", overallAltitudeRange.min, overallAltitudeRange.max))
                                            }
                                            .foregroundStyle(Color.green)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                isAltitudeDetail.toggle()
                                            }
                                            Text(String(format: "%.0f 米", viewModel.samplePath[progressIndex].altitude_avg))
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
                                            Text(String(format: "%.0f 公里/小时", viewModel.samplePath[progressIndex].speed_avg))
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
                        }
                        
                        // 卡牌收益
                        if !detailInfo.cardBonus.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("卡牌收益")
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(Color.secondText)
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
                                            Text("奖励时间: \(bonus.bonusTime)")
                                                .font(.subheadline)
                                                .foregroundColor(.white)
                                            Spacer()
                                        }
                                        Spacer()
                                    }
                                    .padding()
                                    .cornerRadius(12)
                                }
                            }
                        }
                        
                        // team mode 下的队友状态和成绩
                        if !detailInfo.teamMemberScores.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("队伍状态")
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(Color.secondText)
                                ForEach(detailInfo.teamMemberScores) { score in
                                    HStack(spacing: 16) {
                                        HStack(spacing: 10) {
                                            CachedAsyncImage(
                                                urlString: score.userInfo.avatarUrl,
                                                placeholder: Image(systemName: "person"),
                                                errorImage: Image(systemName: "photo.badge.exclamationmark")
                                            )
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                            .exclusiveTouchTapGesture {
                                                appState.navigationManager.append(.userView(id: score.userInfo.userID))
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(score.userInfo.name)
                                                    .font(.subheadline)
                                                    .foregroundColor(Color.secondText)
                                            }
                                        }
                                        Spacer()
                                        HStack {
                                            Text(score.status.rawValue)
                                                .font(.caption)
                                                .padding(.vertical, 5)
                                                .padding(.horizontal, 8)
                                                .foregroundStyle(Color.secondText)
                                                .background(Color.orange.opacity(0.5))
                                                .cornerRadius(10)
                                            Text("成绩: \(TimeDisplay.formattedTime(score.finalTime, showFraction: true))")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding()
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            } else {
                VStack {
                    Spacer()
                    Text("找不到数据")
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
    
    var spacingWidth: CGFloat { return ((UIScreen.main.bounds.width - 32) / (1 + CGFloat(viewModel.samplePath.count)) - 2) }
    
    init(recordID: String) {
        _viewModel = StateObject(wrappedValue: RunningRecordDetailViewModel(recordID: recordID))
    }
    
    var body: some View {
        VStack {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    adjustNavigationPath()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                Spacer()
                Text("running比赛结算")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
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
                    ScrollView(showsIndicators: false) {
                        HStack {
                            Text("成绩与数据")
                                .font(.title2)
                                .bold()
                                .foregroundStyle(Color.secondText)
                            Spacer()
                        }
                        .padding(.bottom, 20)
                        // 成绩总览
                        VStack(spacing: 8) {
                            HStack {
                                Text("原始时间:")
                                    .bold()
                                    .foregroundStyle(Color.secondText)
                                Spacer()
                                Text("\(detailInfo.originalTime)")
                                    .font(.system(.body, design: .rounded))
                                    .bold()
                                    .foregroundStyle(Color.white)
                            }
                            HStack {
                                Text("有效时间:")
                                    .bold()
                                    .foregroundStyle(Color.secondText)
                                Spacer()
                                Text("\(detailInfo.finalTime)")
                                    .font(.system(.body, design: .rounded))
                                    .bold()
                                    .foregroundStyle(Color.white)
                            }
                            HStack {
                                Text("状态:")
                                    .bold()
                                    .foregroundStyle(Color.secondText)
                                Spacer()
                                if detailInfo.status == .completed {
                                    if detailInfo.isFinishComputed == false {
                                        Text("计算中...")
                                            .foregroundColor(.orange)
                                            .bold()
                                    } else {
                                        Text("已完成")
                                            .foregroundColor(.green)
                                            .bold()
                                    }
                                } else if detailInfo.status == .expired {
                                    Text("数据异常")
                                        .foregroundColor(.red)
                                        .bold()
                                } else if detailInfo.status == .invalid {
                                    Text("数据校验失败")
                                        .foregroundColor(.red)
                                        .bold()
                                }
                            }
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
                                                    Text("心率")
                                                    Spacer()
                                                    Text(String(format: "%.0f - %.0f 次/分", rangeMin, rangeMax))
                                                }
                                                .foregroundStyle(Color.red)
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    isHeartDetail.toggle()
                                                }
                                                if let indexMin = viewModel.samplePath[progressIndex].heart_rate_min,
                                                   let indexMax = viewModel.samplePath[progressIndex].heart_rate_max {
                                                    Text(String(format: "%.0f - %.0f 次/分", indexMin, indexMax))
                                                        .padding(.horizontal)
                                                        .padding(.vertical, 10)
                                                        .font(.caption2)
                                                        .foregroundColor(.white)
                                                        .background(Color.red.opacity(0.8))
                                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                                } else {
                                                    Text("无数据")
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
                                            Text("心率")
                                            Spacer()
                                            if let bpmAvg = heartRateAvg {
                                                Text(String(format: "平均 %.0f 次/分", bpmAvg))
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
                                                Text("海拔")
                                                Spacer()
                                                Text(String(format: "%.0f - %.0f 米", overallAltitudeRange.min, overallAltitudeRange.max))
                                            }
                                            .foregroundStyle(Color.green)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                isAltitudeDetail.toggle()
                                            }
                                            Text(String(format: "%.0f 米", viewModel.samplePath[progressIndex].altitude_avg))
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
                                            Text(String(format: "%.0f 公里/小时", viewModel.samplePath[progressIndex].speed_avg))
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
                        }
                        
                        // 卡牌收益
                        if !detailInfo.cardBonus.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("卡牌收益")
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(Color.secondText)
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
                                            Text("奖励时间: \(bonus.bonusTime)")
                                                .font(.subheadline)
                                                .foregroundColor(.white)
                                            Spacer()
                                        }
                                        Spacer()
                                    }
                                    .padding()
                                    .cornerRadius(12)
                                }
                            }
                        }
                        
                        // team mode 下的队友状态和成绩
                        if !detailInfo.teamMemberScores.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("队伍状态")
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(Color.secondText)
                                ForEach(detailInfo.teamMemberScores) { score in
                                    HStack(spacing: 16) {
                                        HStack(spacing: 10) {
                                            CachedAsyncImage(
                                                urlString: score.userInfo.avatarUrl,
                                                placeholder: Image(systemName: "person"),
                                                errorImage: Image(systemName: "photo.badge.exclamationmark")
                                            )
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                            .exclusiveTouchTapGesture {
                                                appState.navigationManager.append(.userView(id: score.userInfo.userID))
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(score.userInfo.name)
                                                    .font(.subheadline)
                                                    .foregroundColor(Color.secondText)
                                            }
                                        }
                                        Spacer()
                                        HStack {
                                            Text(score.status.rawValue)
                                                .font(.caption)
                                                .padding(.vertical, 5)
                                                .padding(.horizontal, 8)
                                                .foregroundStyle(Color.secondText)
                                                .background(Color.orange.opacity(0.5))
                                                .cornerRadius(10)
                                            Text("成绩: \(TimeDisplay.formattedTime(score.finalTime, showFraction: true))")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding()
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            } else {
                VStack {
                    Spacer()
                    Text("找不到数据")
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
