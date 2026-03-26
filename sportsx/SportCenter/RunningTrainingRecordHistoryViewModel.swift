//
//  RunningTrainingRecordHistoryViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2026/3/16.
//

import Foundation
import Combine


@MainActor
class RunningTrainingRecordHistoryViewModel: ObservableObject {
    @Published var calendarDays: [CalendarDay] = []
    @Published var records: [RunningFreeTrainingRecord] = []
    
    @Published var currentMonth: Date = Date()
    @Published var selectedDay: Date = Date()

    private let calendar = Calendar.current
    
    private var monthHistoryCache: [String: [RunningTrainingStatesHistoryInfo]] = [:]
    private var recordsCache: [String: [RunningFreeTrainingRecord]] = [:]

    var monthText: String {
        monthTextFormatter.string(from: currentMonth)
    }
    
    private let monthTextFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy MMMM"
        return f
    }()
    
    private let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        f.timeZone = .current
        return f
    }()
    
    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()
    
    init() {
        loadMonth()
    }

    func prevMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newDate
            loadMonth()
        }
    }

    func nextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newDate
            loadMonth()
        }
    }

    func selectDay(_ day: CalendarDay) {
        if day.date != selectedDay {
            selectedDay = day.date
            fetchRecords(for: selectedDay)
        }
    }

    private func loadMonth() {
        // Update selected day when month changes
        let today = Date()
        if calendar.isDate(today, equalTo: currentMonth, toGranularity: .month) {
            selectedDay = today
        } else {
            var comps = calendar.dateComponents([.year, .month], from: currentMonth)
            comps.day = 1
            selectedDay = calendar.date(from: comps) ?? today
        }

        // Build calendar data
        var days: [CalendarDay] = []
        let range = calendar.range(of: .day, in: .month, for: currentMonth) ?? 1..<29

        for d in range {
            var components = calendar.dateComponents([.year, .month], from: currentMonth)
            components.day = d
            let date = calendar.date(from: components) ?? Date()
            days.append(
                CalendarDay(
                    date: date,
                    dayNumber: d,
                    delta: 0
                )
            )
        }
        calendarDays = days
        Task {
            await fetchHistory()
            fetchRecords(for: selectedDay)
        }
    }

    private func fetchHistory() async {
        let monthStr = monthFormatter.string(from: currentMonth)
        // 查缓存
        if let cached = monthHistoryCache[monthStr] {
            applyHistory(cached)
            return
        }
        guard var components = URLComponents(string: "/training/running/training_states/month") else { return }
        components.queryItems = [
            URLQueryItem(name: "month", value: monthStr)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        let result = await NetworkService.sendAsyncRequest(with: request, decodingType: RunningTrainingStatesHistoryResponse.self, showLoadingToast: true, showErrorToast: true)
        switch result {
        case .success(let data):
            if let unwrappedData = data {
                // 存缓存
                self.monthHistoryCache[monthStr] = unwrappedData.history
                DispatchQueue.main.async {
                    self.applyHistory(unwrappedData.history)
                }
            }
        default: break
        }
    }
    
    private func applyHistory(_ history: [RunningTrainingStatesHistoryInfo]) {
        var deltaMap: [Int: Int] = [:]

        for item in history {
            if let date = dayFormatter.date(from: item.date) {
                let day = calendar.component(.day, from: date)
                deltaMap[day] = item.delta_state
            }
        }

        calendarDays = calendarDays.map { day in
            let newDelta = deltaMap[day.dayNumber] ?? 0
            return CalendarDay(
                date: day.date,
                dayNumber: day.dayNumber,
                delta: newDelta
            )
        }
    }
    
    private func fetchRecords(for date: Date) {
        let dayStr = dayFormatter.string(from: date)
        
        // 如果 history 已经加载，并且该天 delta == 0，或无数据则直接跳过请求
        let monthStr = monthFormatter.string(from: currentMonth)
        if let history = monthHistoryCache[monthStr] {
            if let item = history.first(where: { $0.date == dayStr }) {
                if item.delta_state == 0 {
                    recordsCache[dayStr] = []
                    records = []
                    return
                }
            } else {
                // history 中没有该日期，说明 delta == 0
                recordsCache[dayStr] = []
                records = []
                return
            }
        }
        
        // 查缓存
        if let cached = recordsCache[dayStr] {
            records = cached
            return
        }
        guard var components = URLComponents(string: "/training/running/training_records/day") else { return }
        components.queryItems = [
            URLQueryItem(name: "day", value: dayStr)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: TrainingRecordsResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        let newRecords = unwrappedData.records.map { RunningFreeTrainingRecord(from: $0) }
                        // 存缓存
                        self.recordsCache[dayStr] = newRecords
                        self.records = newRecords
                    }
                }
            default: break
            }
        }
    }
}

class RunningTrainingStatesHistoryInfo: Codable {
    let date: String        // "2026-01-17"
    let delta_state: Int
}

struct RunningTrainingStatesHistoryResponse: Codable {
    let history: [RunningTrainingStatesHistoryInfo]
}
