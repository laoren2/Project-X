//
//  TrainingModuleView.swift
//  sportsx
//
//  个人主页「训练」模块：展示当前 momentum、最近 7 天训练折线图（时间/momentum/距离切换、
//  7 区域点击高亮），以及选中当天的训练记录列表（复用 TrainingRecordCardView）。
//  sport/userID 由外部传入，支持查看本人或他人（接口带 user_id）。
//

import SwiftUI


// 折线图指标
enum TrainingMetric: String, CaseIterable, Hashable {
    case time
    case momentum
    case distance

    var titleKey: String {
        switch self {
        case .time: return "training.summary.metric.time"
        case .momentum: return "training.summary.metric.momentum"
        case .distance: return "training.summary.metric.distance"
        }
    }

    // 折线图用的数值（无坐标轴，仅取相对大小）
    func chartValue(_ d: WeeklyTrainingDayDTO) -> Double {
        switch self {
        case .time: return d.total_time / 3600.0     // 小时
        case .momentum: return Double(d.delta_state)
        case .distance: return d.total_distance      // km
        }
    }
}

struct WeeklyTrainingDayDTO: Codable {
    let date: String
    let total_time: Double       // 秒
    let delta_state: Int
    let total_distance: Double    // km
}

struct WeeklyTrainingSummaryResponse: Codable {
    let current_state: Int
    let days: [WeeklyTrainingDayDTO]
}


struct TrainingModuleView: View {
    let sport: SportName
    let userID: String

    @State private var currentState: Int = 0
    @State private var days: [WeeklyTrainingDayDTO] = []
    @State private var metric: TrainingMetric = .time
    @State private var selectedIndex: Int = 6
    @State private var dayRecords: [TrainingRecordInfo] = []
    @State private var dayRecordsCache: [String: [TrainingRecordInfo]] = [:]   // 按日期缓存，切换日期不重复请求
    @State private var isSummaryLoading: Bool = true
    @State private var isDayLoading: Bool = false
    @State private var didLoad: Bool = false

    private static let isoDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()
    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()
    private static let headerFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd EEE"
        return f
    }()

    var body: some View {
        VStack(spacing: 16) {
            if isSummaryLoading {
                skeleton
            } else {
                momentumBar
                metricSelectorRow
                WeeklyTrainingChartView(
                    values: days.map { metric.chartValue($0) },
                    labels: days.map { weekday(for: $0.date) },
                    selectedIndex: $selectedIndex
                )
                .frame(height: 170)

                if days.indices.contains(selectedIndex) {
                    HStack {
                        Text(headerText(for: days[selectedIndex].date))
                            .font(.subheadline)
                            .foregroundStyle(Color.secondText)
                        Spacer()
                        metricValueText(days[selectedIndex])
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                }

                dayRecordsList
            }
            Spacer(minLength: 0)
        }
        .padding()
        .frame(minHeight: 600)
        .onStableAppear {
            if !didLoad { fetchSummary() }
        }
        .onValueChange(of: selectedIndex) { _, _ in
            fetchDayRecords()
        }
        .onValueChange(of: sport) { _, _ in
            fetchSummary()
        }
    }

    // MARK: - 子视图

    private var momentumBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 5) {
                Text("training.sport_state")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(currentState)")
            }
            .foregroundStyle(Color.white)
            HStack {
                Image("momentum")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20)
                ProgressBar(progress: Double(currentState) / 100)
                    .frame(height: 20)
            }
        }
        .padding()
        .background(.white.opacity(0.3))
        .cornerRadius(12)
    }

    private var metricSelectorRow: some View {
        HStack {
            Text("training.summary.title")
                .font(.headline)
                .foregroundStyle(Color.white)
            Spacer()
            CapsuleScrollSelector(
                options: TrainingMetric.allCases,
                selection: $metric,
                titleKey: { $0.titleKey },
                expandedWidth: 220,
                backgroundColor: Color.white.opacity(0.2)
            )
        }
    }

    @ViewBuilder
    private var dayRecordsList: some View {
        if isDayLoading {
            ProgressView()
                .padding(.vertical, 30)
        } else if dayRecords.isEmpty {
            Text("training.history.no_record")
                .font(.subheadline)
                .foregroundStyle(Color.secondText)
                .padding(.vertical, 30)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(dayRecords, id: \.record_id) { info in
                    recordCard(info)
                }
            }
        }
    }

    @ViewBuilder
    private func recordCard(_ info: TrainingRecordInfo) -> some View {
        if sport == .Bike {
            BikeTrainingRecordCardView(record: BikeFreeTrainingRecord(from: info))
        } else {
            RunningTrainingRecordCardView(record: RunningFreeTrainingRecord(from: info))
        }
    }

    @ViewBuilder
    private func metricValueText(_ d: WeeklyTrainingDayDTO) -> some View {
        switch metric {
        case .time:
            Text(String(format: "%.1f ", d.total_time / 3600)) + Text("time.hour")
        case .momentum:
            Text(d.delta_state >= 0 ? "+\(d.delta_state)" : "\(d.delta_state)")
        case .distance:
            Text(String(format: "%.2f ", d.total_distance)) + Text("distance.km")
        }
    }

    private var skeleton: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.5)).frame(height: 80)
            RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.5)).frame(height: 170)
            RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.5)).frame(height: 70)
        }
    }

    // MARK: - 辅助

    private func weekday(for dateStr: String) -> String {
        guard let date = Self.isoDayFormatter.date(from: dateStr) else { return "" }
        return Self.weekdayFormatter.string(from: date)
    }

    private func headerText(for dateStr: String) -> String {
        guard let date = Self.isoDayFormatter.date(from: dateStr) else { return dateStr }
        return Self.headerFormatter.string(from: date)
    }

    // MARK: - 网络

    private func fetchSummary() {
        isSummaryLoading = true
        // 重新拉取周汇总（含切换运动）时，旧的当天记录缓存已失效
        dayRecordsCache.removeAll()
        guard var components = URLComponents(string: "/training/\(sport.rawValue)/weekly_training_summary") else { return }
        components.queryItems = [URLQueryItem(name: "user_id", value: userID)]
        guard let urlPath = components.string else { return }

        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        NetworkService.sendRequest(
            with: request,
            decodingType: WeeklyTrainingSummaryResponse.self,
            showLoadingToast: false,
            showErrorToast: true
        ) { result in
            DispatchQueue.main.async {
                isSummaryLoading = false
                didLoad = true
                switch result {
                case .success(let data):
                    guard let data else { return }
                    currentState = data.current_state
                    days = data.days
                    selectedIndex = max(0, data.days.count - 1)
                    fetchDayRecords()
                default:
                    break
                }
            }
        }
    }

    private func fetchDayRecords() {
        guard days.indices.contains(selectedIndex) else {
            dayRecords = []
            return
        }
        let day = days[selectedIndex].date
        // 命中缓存直接展示，避免切换日期重复请求
        if let cached = dayRecordsCache[day] {
            dayRecords = cached
            isDayLoading = false
            return
        }
        isDayLoading = true
        guard var components = URLComponents(string: "/training/\(sport.rawValue)/training_records/day") else { return }
        components.queryItems = [
            URLQueryItem(name: "day", value: day),
            URLQueryItem(name: "user_id", value: userID)
        ]
        guard let urlPath = components.string else { return }

        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        NetworkService.sendRequest(
            with: request,
            decodingType: TrainingRecordsResponse.self,
            showLoadingToast: false,
            showErrorToast: true
        ) { result in
            DispatchQueue.main.async {
                isDayLoading = false
                switch result {
                case .success(let data):
                    let records = data?.records ?? []
                    dayRecordsCache[day] = records
                    dayRecords = records
                default:
                    break
                }
            }
        }
    }
}
