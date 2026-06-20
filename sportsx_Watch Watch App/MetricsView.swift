//
//  MetricsView.swift
//  sportsx
//
//  Created by 任杰 on 2025/2/18.
//

import SwiftUI

struct MetricsView: View {
    @EnvironmentObject var workoutManager: WatchDataManager
    @Environment(\.isLuminanceReduced) var isLuminanceReduced
    // 纵向分页：0 = 时间页(首屏)，1 = 统计页
    @State private var page = 0
    // PB 对比：是否显示距离差（默认时间差），点击切换
    @State private var showPbDistance = false

    private struct MetricsTimelineSchedule: TimelineSchedule {
        var startDate: Date

        init(from startDate: Date) {
            self.startDate = startDate
        }

        func entries(from startDate: Date, mode: TimelineScheduleMode) -> PeriodicTimelineSchedule.Entries {
            PeriodicTimelineSchedule(
                from: self.startDate,
                by: (mode == .lowFrequency ? 1.0 : 1.0 / 30.0)
            ).entries(
                from: startDate,
                mode: mode
            )
        }
    }

    var body: some View {
        // 纵向分页 TabView：首屏只放「进行时间」(可读性/激励性最高)，下翻一页是完整本地统计。
        // 后续适配 mode 时再在时间页叠加检查点进度 / 排名预测 / 雷达指引等元素。
        TabView(selection: $page) {
            timePage.tag(0)
            statsPage.tag(1)
        }
        .tabViewStyle(.verticalPage)
        .onChange(of: isLuminanceReduced) {
            // 熄屏(进入 AOD)时回到时间页，保证抬腕/AOD 优先看到时间
            if isLuminanceReduced {
                page = 0
            }
        }
    }

    // MARK: - 第 1 页：race/route = 名次环 + 时间 + PB 对比；free = 雷达指引
    @ViewBuilder private var timePage: some View {
        if workoutManager.workoutMode.isPaceCompare {
            paceComparePage
        } else {
            radarPage
        }
    }

    private var elapsedTime: some View {
        TimelineView(
            MetricsTimelineSchedule(from: workoutManager.builder?.startDate ?? Date())
        ) { _ in
            ElapsedTimeView(
                elapsedTime: workoutManager.builder?.elapsedTime ?? 0,
                showSubseconds: !isLuminanceReduced
            )
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .foregroundColor(.yellow)
        }
    }

    // race / route：外圈名次环 + 中间时间 + PB 对比
    private var paceComparePage: some View {
        ZStack {
            rankRing
            rankLabel
            VStack(spacing: 6) {
                elapsedTime
                    .font(.system(size: 38, weight: .semibold, design: .rounded).monospacedDigit())
                pbDeltaView
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // free：圆形雷达，中心叠加进行时间
    private var radarPage: some View {
        ZStack {
            GridRadarView(
                grids: workoutManager.live.grids,
                userLocation: workoutManager.currentLocation,
                headingDegrees: headingDegrees
            )
            elapsedTime
                .font(.system(size: 22, weight: .semibold, design: .rounded).monospacedDigit())
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // 设备朝向：优先真北，退化到磁北/移动航向，再退化到北朝上
    private var headingDegrees: Double {
        if let h = workoutManager.heading {
            if h.trueHeading >= 0 { return h.trueHeading }
            if h.magneticHeading >= 0 { return h.magneticHeading }
        }
        if let course = workoutManager.currentLocation?.course, course >= 0 { return course }
        return 0
    }

    // 预测名次填充比例：越靠前越满（rank 1 → 满环）
    private var rankFraction: Double {
        let live = workoutManager.live
        guard !live.locked, let rank = live.rank, live.total > 0 else { return 0 }
        return max(0, min(1, Double(live.total - rank + 1) / Double(live.total)))
    }

    // 外圈 3/4 橙色环 + 进度末端圆点
    private var rankRing: some View {
        RankRingView(fraction: rankFraction)
            .animation(.easeOut(duration: 0.4), value: rankFraction)
    }

    // 底部缺口处的名次数值：名次越靠前字号越大，变化时弹性放缩
    @ViewBuilder private var rankLabel: some View {
        let live = workoutManager.live
        if !live.locked, let rank = live.rank, live.total > 0 {
            VStack {
                Spacer()
                Text("# \(rank) / \(live.total)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundColor(.orange)
                    .scaleEffect(0.85 + 0.6 * rankFraction)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.bottom, 4)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: rank)
            }
        }
    }

    // 与 PB 对比：白色数值 + 绿(领先)/红(落后)三角图标；点击切换时间差 ↔ 距离差
    @ViewBuilder private var pbDeltaView: some View {
        let live = workoutManager.live
        let delta = showPbDistance ? live.pbDeltaDistance : live.pbDeltaTime
        Group {
            if !live.locked, live.hasPB, let d = delta {
                let ahead = d >= 0
                HStack(spacing: 3) {
                    Image(systemName: ahead ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .foregroundStyle(ahead ? Color.green : Color.red)
                    if showPbDistance {
                        (Text(String(format: "%.0f ", abs(d))) + Text("distance.m"))
                            .foregroundColor(.white)
                    } else {
                        Text(ElapsedTimeView.formatted(abs(d), showSubseconds: false))
                            .foregroundColor(.white)
                    }
                }
                .font(.system(size: 16, weight: .semibold, design: .rounded).monospacedDigit())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            } else {
                Text("--")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { showPbDistance.toggle() }
    }

    // MARK: - 第 2 页：本地实时统计(2 列，纵向滚动防裁切)
    private var statsPage: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(metrics) { metric in
                    MetricCell(metric: metric)
                }
            }
            .scenePadding(.horizontal)
            .padding(.vertical, 4)
        }
    }

    // MARK: - 统计项(只收集当前可用的，交给网格自动流式排布)
    private var metrics: [Metric] {
        var list: [Metric] = [
            Metric(id: "distance", title: "competition.realtime.distance",
                   value: distanceValue, unit: distanceUnit, tint: .yellow),
            Metric(id: "heartrate", title: "competition.realtime.heartrate",
                   value: format(workoutManager.heartRate), unit: "heartrate.unit", tint: .pink)
        ]

        if workoutManager.sportType == .Running {
            list.append(Metric(id: "pace", title: "common.pace",
                               value: paceValue, unit: "metric.pace.unit"))
        } else {
            list.append(Metric(id: "speed", title: "metric.speed",
                               value: speedValue, unit: "speed.km/h"))
        }

        list.append(Metric(id: "energy", title: "competition.realtime.energy",
                           value: format(workoutManager.totalEnergy), unit: "energy.unit"))

        if let power = workoutManager.latestPower {
            list.append(Metric(id: "power", title: "competition.realtime.power",
                               value: format(power), unit: "power.unit"))
        }

        if workoutManager.sportType == .Running, let cadence = workoutManager.stepCadence {
            list.append(Metric(id: "cadence", title: "competition.result.stepcadence",
                               value: format(cadence), unit: "stepCadence.unit"))
        } else if workoutManager.sportType == .Bike, let cadence = workoutManager.cycleCadence {
            list.append(Metric(id: "cadence", title: "competition.result.pedalcadence",
                               value: format(cadence), unit: "pedalCadence.unit"))
        }
        return list
    }

    // MARK: - 数值格式化
    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }

    private var distanceValue: String {
        let meters = workoutManager.distance
        return meters < 1000
            ? meters.formatted(.number.precision(.fractionLength(0)))
            : (meters / 1000).formatted(.number.precision(.fractionLength(2)))
    }

    private var distanceUnit: LocalizedStringKey {
        workoutManager.distance < 1000 ? "distance.m" : "distance.km"
    }

    private var speedValue: String {
        let seconds = workoutManager.builder?.elapsedTime ?? 0
        guard seconds > 0, workoutManager.distance > 0 else { return "--" }
        let kmh = (workoutManager.distance / 1000) / (seconds / 3600)
        return kmh.formatted(.number.precision(.fractionLength(1)))
    }

    private var paceValue: String {
        let seconds = workoutManager.builder?.elapsedTime ?? 0
        let km = workoutManager.distance / 1000
        guard km > 0.01, seconds > 0 else { return "--" }
        let secPerKm = seconds / km
        return String(format: "%d'%02d\"", Int(secPerKm) / 60, Int(secPerKm) % 60)
    }
}

// 单个统计项数据
private struct Metric: Identifiable {
    let id: String
    let title: LocalizedStringKey
    let value: String
    var unit: LocalizedStringKey? = nil
    var tint: Color = .white
}

// 单格：小标题 + 大数值 + 单位(为窄列优化)
private struct MetricCell: View {
    let metric: Metric

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(metric.title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(metric.value)
                    .font(.system(size: 24, weight: .semibold, design: .rounded).monospacedDigit())
                if let unit = metric.unit {
                    Text(unit)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(metric.tint)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    let workout = WatchDataManager.shared
    workout.heartRate = 180
    workout.summaryViewData = SummaryViewData(
        avgHeartRate: 0,
        totalEnergy: 0,
        avgPower: 0,
        distance: 0,
        totalTime: 0,
        stepCadence: nil,
        cycleCadence: nil
    )
    return MetricsView()
        .environmentObject(workout)
}
