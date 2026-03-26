//
//  TrainingRecord.swift
//  sportsx
//
//  Created by 任杰 on 2026/3/10.
//
import SwiftUI
import Foundation
import MapKit


struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date
    let dayNumber: Int
    let delta: Int

    var deltaText: String {
        if delta > 0 {
            return "+\(delta)"
        } else if delta < 0 {
            return "\(delta)"
        } else {
            return "+0"
        }
    }

    var foregroundColor: Color {
        if delta > 0 {
            return Color.green
        } else if delta < 0 {
            return Color.red
        } else {
            return Color.white
        }
    }
    
    var backgroundColor: Color {
        if delta > 0 {
            return Color.green.opacity(0.2)
        } else if delta < 0 {
            return Color.red.opacity(0.2)
        } else {
            return .gray
        }
    }
    
    func isSameDay(as date: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(self.date, inSameDayAs: date)
    }
}

struct TrainingStateDay: Identifiable {
    let id = UUID()
    let date: Date
    let value: Int
    let delta: Int
}

struct BikeFreeTrainingRecord: Identifiable {
    var id: String { record_id }
    let record_id: String
    let endTime: Date?
    let delta: Int
    
    init(from record: TrainingRecordInfo) {
        self.record_id = record.record_id
        self.delta = record.delta_state
        self.endTime =  DateParser.parseISO8601(record.end_time)
    }
}

struct RunningFreeTrainingRecord: Identifiable {
    var id: String { record_id }
    let record_id: String
    let endTime: Date?
    let delta: Int
    
    init(from record: TrainingRecordInfo) {
        self.record_id = record.record_id
        self.delta = record.delta_state
        self.endTime =  DateParser.parseISO8601(record.end_time)
    }
}

struct TrainingRecordInfo: Codable {
    let record_id: String
    let delta_state: Int
    let end_time: String
}

struct TrainingRecordsResponse: Codable {
    let records: [TrainingRecordInfo]
}
