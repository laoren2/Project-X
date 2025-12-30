//
//  BikeRecordBackendView.swift
//  sportsx
//
//  Created by 任杰 on 2025/11/13.
//

#if DEBUG
import SwiftUI

struct BikeRecordBackendView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel = BikeRecordBackendViewModel()
    
    var selectedRecordID: String = ""
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: {
                    appState.navigationManager.removeLast()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                }
                
                Spacer()
                
                Text("自行车记录校验")
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                // 平衡布局的空按钮
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            
            Spacer()
            
            Button("查询待校验记录") {
                viewModel.records.removeAll()
                viewModel.currentPage = 1
                viewModel.queryRecords()
            }
            .padding()
            
            // 搜索结果展示，每条记录末尾添加一个"修改"按钮
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(viewModel.records) { record in
                        BikeUnVerifiedCardView(viewModel: viewModel, record: record)
                            .onAppear {
                                if record == viewModel.records.last && viewModel.hasMoreRecords {
                                    viewModel.queryRecords()
                                }
                            }
                    }
                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top)
            }
            .background(.gray.opacity(0.1))
            .cornerRadius(10)
        }
        .padding(.horizontal)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .sheet(item: $viewModel.selectedRecord) { record in
            BikeVerifiedDetailView(viewModel: viewModel, record: record)
        }
    }
}

struct BikeUnVerifiedCardView: View {
    @ObservedObject var viewModel: BikeRecordBackendViewModel
    let record: BikeUnverifiedRecordInfo
    
    var body: some View {
        HStack {
            Image(systemName: "v.circle.fill")
                .foregroundStyle(record.is_vip ? Color.red : Color.gray)
            Text(LocalizedStringKey(DateDisplay.formattedDate(record.finished_at)))
            Spacer()
            Button("详情") {
                viewModel.selectedRecord = record
            }
            if let score = record.validation_score {
                Text(String(format: "%.2f", score))
            } else {
                Text("未知")
            }
        }
    }
}

struct BikeVerifiedDetailView: View {
    @ObservedObject var viewModel: BikeRecordBackendViewModel
    let record: BikeUnverifiedRecordInfo
    @Environment(\.dismiss) private var dismiss
    
    @State private var progressIndex: Int = 0
    @State var isHeartDetail: Bool = false
    @State var isAltitudeDetail: Bool = false
    @State var isSpeedDetail: Bool = false
    @State var isPedalCountDetail: Bool = false
    @State var isPedalCadenceDetail: Bool = false
    let formHeight: CGFloat = 80
    
    var overallHeartRateRange: (min: Double?, max: Double?) {
        let mins = record.samplePath.compactMap { $0.heart_rate_min }
        let maxs = record.samplePath.compactMap { $0.heart_rate_max }
        if mins.isEmpty && maxs.isEmpty {
            return (nil, nil)
        }
        let minVal = mins.min()
        let maxVal = maxs.max()
        return (minVal, maxVal)
    }
    
    var overallAltitudeRange: (min: Double, max: Double) {
        let altitudes = record.samplePath.compactMap { $0.altitude_avg }
        let minVal = altitudes.min() ?? 0
        let maxVal = altitudes.max() ?? 0
        return (minVal, maxVal)
    }
    
    var overallSpeedRange: (min: Double, max: Double) {
        let altitudes = record.samplePath.compactMap { $0.speed_avg }
        let minVal = altitudes.min() ?? 0
        let maxVal = altitudes.max() ?? 0
        return (minVal, maxVal)
    }
    
    var overallPedalCountRange: (min: Double, max: Double) {
        let pedals = record.samplePath.map { $0.pedal_count_avg }
        let minVal = pedals.min() ?? 0
        let maxVal = pedals.max() ?? 0
        return (minVal, maxVal)
    }
    
    var overallPedalCadenceRange: (min: Double?, max: Double?) {
        let pedals = record.samplePath.compactMap { $0.pedal_cadence_avg }
        if pedals.isEmpty {
            return (nil, nil)
        }
        let minVal = pedals.min() ?? 0
        let maxVal = pedals.max() ?? 0
        return (minVal, maxVal)
    }
    
    var heartRateAvg: Double? {
        let validHeartRates = record.basePath.compactMap { $0.heart_rate }
        guard !validHeartRates.isEmpty else { return nil }
        return validHeartRates.reduce(0, +) / Double(validHeartRates.count)
    }
    
    var speedAvg: Double {
        guard !record.basePath.isEmpty else { return 0 }
        
        var totalDistance: Double = 0
        for i in 0..<(record.basePath.count - 1) {
            let p1 = record.basePath[i]
            let p2 = record.basePath[i + 1]
            totalDistance += GeographyTool.haversineDistance(
                lat1: p1.lat, lon1: p1.lon,
                lat2: p2.lat, lon2: p2.lon
            )
        }
        let duration = max(record.basePath.last!.timestamp - record.basePath.first!.timestamp, 0.0001)
        return (totalDistance / duration) * 3.6
    }
    
    var altitudeAvg: Double {
        let altitudes = record.basePath.map { $0.altitude }
        guard !altitudes.isEmpty else { return 0 }
        return altitudes.reduce(0, +) / Double(altitudes.count)
    }
    
    var pedalCadenceAvg: Double? {
        let pedals = record.path.compactMap { $0.pedal_cadence }
        guard !pedals.isEmpty else { return nil }
        return pedals.reduce(0, +) / Double(pedals.count)
    }
    
    var pedalCountAvg: Double {
        let pedals = record.path.map { $0.estimate_pedal_count }
        guard !pedals.isEmpty else { return 0 }
        return 20.0 * pedals.reduce(0, +) / Double(pedals.count)
    }
    
    var spacingWidth: CGFloat { return ((UIScreen.main.bounds.width - 32) / (1 + CGFloat(record.samplePath.count)) - 2) }
    
    
    var body: some View {
        VStack {
            HStack {
                Button("拒绝") {
                    viewModel.handleVerify(recordID: record.record_id, result: false)
                }
                Spacer()
                Button("通过") {
                    viewModel.handleVerify(recordID: record.record_id, result: true)
                }
            }
            .padding()
            
            ZStack(alignment: .bottom) {
                GradientPathMapView(path: record.basePath, highlightedIndex: progressIndex)
                    .frame(height: 280)
                    .cornerRadius(12)
                if !record.samplePath.isEmpty {
                    // 当前选中时间段
                    HStack {
                        Text(TimeDisplay.formattedTime(record.samplePath[progressIndex].timestamp_min - record.samplePath[0].timestamp_min))
                        Spacer()
                        Text(TimeDisplay.formattedTime(record.samplePath[progressIndex].timestamp_max - record.samplePath[0].timestamp_min))
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
                                    if let indexMin = record.samplePath[progressIndex].heart_rate_min,
                                       let indexMax = record.samplePath[progressIndex].heart_rate_max {
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
                                        ForEach(record.samplePath.indices, id: \.self) { i in
                                            // 根据采样数据心率区间的最大值和最小值计算柱状图高度
                                            if let hrMin = record.samplePath[i].heart_rate_min,
                                               let hrMax = record.samplePath[i].heart_rate_max {
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
                                    GestureOverlayView(pointsCount: record.samplePath.count, progressIndex: $progressIndex)
                                }
                                .frame(height: formHeight)
                                Rectangle()
                                    .foregroundStyle(Color.gray)
                                    .frame(height: 1)
                                HStack {
                                    Text("00:00")
                                    Spacer()
                                    if let EndTime = record.basePath.last?.timestamp, let startTime = record.basePath.first?.timestamp {
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
                                Text(String(format: "%.0f 米", record.samplePath[progressIndex].altitude_avg))
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .background(Color.green.opacity(0.8))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            ZStack {
                                HStack(alignment: .bottom, spacing: spacingWidth) {
                                    ForEach(record.samplePath.indices, id: \.self) { i in
                                        let overall = (overallAltitudeRange.max - overallAltitudeRange.min)
                                        let ratio = overall > 0 ? (record.samplePath[i].altitude_avg - overallAltitudeRange.min) / overall : 1/2
                                        let height = max(formHeight * ratio, 0) + 4
                                        
                                        RoundedRectangle(cornerRadius: 1)
                                            .fill(i == progressIndex ? Color.green : Color.gray.opacity(0.5))
                                            .frame(width: 2, height: height)
                                    }
                                }
                                GestureOverlayView(pointsCount: record.samplePath.count, progressIndex: $progressIndex)
                            }
                            .frame(height: formHeight)
                            Rectangle()
                                .foregroundStyle(Color.gray)
                                .frame(height: 1)
                            HStack {
                                Text("00:00")
                                Spacer()
                                if let EndTime = record.basePath.last?.timestamp, let startTime = record.basePath.first?.timestamp {
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
                                Text(String(format: "%.0f 公里/小时", record.samplePath[progressIndex].speed_avg))
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .background(Color.orange.opacity(0.8))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            ZStack {
                                HStack(alignment: .bottom, spacing: spacingWidth) {
                                    ForEach(record.samplePath.indices, id: \.self) { i in
                                        let overall = (overallSpeedRange.max - overallSpeedRange.min)
                                        let ratio = overall > 0 ? (record.samplePath[i].speed_avg - overallSpeedRange.min) / overall : 1/2
                                        let height = max(formHeight * ratio, 0) + 4
                                        
                                        RoundedRectangle(cornerRadius: 1)
                                            .fill(i == progressIndex ? Color.orange : Color.gray.opacity(0.5))
                                            .frame(width: 2, height: height)
                                    }
                                }
                                GestureOverlayView(pointsCount: record.samplePath.count, progressIndex: $progressIndex)
                            }
                            .frame(height: formHeight)
                            Rectangle()
                                .foregroundStyle(Color.gray)
                                .frame(height: 1)
                            HStack {
                                Text("00:00")
                                Spacer()
                                if let EndTime = record.basePath.last?.timestamp, let startTime = record.basePath.first?.timestamp {
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
                    
                    if let rangeMin = overallPedalCadenceRange.min, let rangeMax = overallPedalCadenceRange.max {
                        if isPedalCadenceDetail {
                            VStack {
                                ZStack(alignment: .center) {
                                    HStack {
                                        Text("步频")
                                        Spacer()
                                        Text(String(format: "%.0f - %.0f 次/分", rangeMin, rangeMax))
                                    }
                                    .foregroundStyle(Color.blue)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        isPedalCadenceDetail.toggle()
                                    }
                                    if let avg = record.samplePath[progressIndex].pedal_cadence_avg {
                                        Text(String(format: "%.0f 次/分", avg))
                                            .padding(.horizontal)
                                            .padding(.vertical, 10)
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                            .background(Color.blue.opacity(0.8))
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
                                ZStack {
                                    HStack(alignment: .bottom, spacing: spacingWidth) {
                                        ForEach(record.samplePath.indices, id: \.self) { i in
                                            if let pedal_avg = record.samplePath[i].pedal_cadence_avg {
                                                let overall = rangeMax - rangeMin
                                                let ratio = overall > 0 ? (pedal_avg - rangeMin) / overall : 1/2
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
                                    GestureOverlayView(pointsCount: record.samplePath.count, progressIndex: $progressIndex)
                                }
                                .frame(height: formHeight)
                                Rectangle()
                                    .foregroundStyle(Color.gray)
                                    .frame(height: 1)
                                HStack {
                                    Text("00:00")
                                    Spacer()
                                    if let EndTime = record.basePath.last?.timestamp, let startTime = record.basePath.first?.timestamp {
                                        Text("\(TimeDisplay.formattedTime(EndTime - startTime))")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(Color.gray)
                            }
                        } else {
                            HStack {
                                Text("步频")
                                Spacer()
                                if let pedalAvg = pedalCadenceAvg {
                                    Text(String(format: "平均 %.0f 次/分", pedalAvg))
                                }
                            }
                            .padding()
                            .foregroundStyle(Color.white)
                            .background(Color.blue.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .onTapGesture {
                                isPedalCadenceDetail.toggle()
                            }
                        }
                    }
                    if isPedalCountDetail {
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
                                    isPedalCountDetail.toggle()
                                }
                                Text(String(format: "%.0f 次/分", record.samplePath[progressIndex].pedal_count_avg))
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .background(Color.pink.opacity(0.8))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            ZStack {
                                HStack(alignment: .bottom, spacing: spacingWidth) {
                                    ForEach(record.samplePath.indices, id: \.self) { i in
                                        let overall = (overallPedalCountRange.max - overallPedalCountRange.min)
                                        let ratio = overall > 0 ? (record.samplePath[i].pedal_count_avg - overallPedalCountRange.min) / overall : 1/2
                                        let height = max(formHeight * ratio, 0) + 4
                                        
                                        RoundedRectangle(cornerRadius: 1)
                                            .fill(i == progressIndex ? Color.pink : Color.gray.opacity(0.5))
                                            .frame(width: 2, height: height)
                                    }
                                }
                                GestureOverlayView(pointsCount: record.samplePath.count, progressIndex: $progressIndex)
                            }
                            .frame(height: formHeight)
                            Rectangle()
                                .foregroundStyle(Color.gray)
                                .frame(height: 1)
                            HStack {
                                Text("00:00")
                                Spacer()
                                if let EndTime = record.basePath.last?.timestamp, let startTime = record.basePath.first?.timestamp {
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
                            isPedalCountDetail.toggle()
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 50)
            }
        }
    }
}

#endif
