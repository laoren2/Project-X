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
    let recordCount: Int      // 当天训练记录数，用于日期右上角角标

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
            return Color.green.opacity(0.4)
        } else if delta < 0 {
            return Color.red.opacity(0.4)
        } else {
            return Color.secondBackground.opacity(0.4)
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
    let trainingType: TrainingType
    let track: [CLLocationCoordinate2D]

    init(from record: TrainingRecordInfo) {
        self.record_id = record.record_id
        self.delta = record.delta_state
        self.endTime =  DateParser.parseISO8601(record.end_time)
        self.trainingType = record.training_type
        self.track = record.track.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
    }
}

struct RunningFreeTrainingRecord: Identifiable {
    var id: String { record_id }
    let record_id: String
    let endTime: Date?
    let delta: Int
    let trainingType: TrainingType
    let track: [CLLocationCoordinate2D]

    init(from record: TrainingRecordInfo) {
        self.record_id = record.record_id
        self.delta = record.delta_state
        self.endTime =  DateParser.parseISO8601(record.end_time)
        self.trainingType = record.training_type
        self.track = record.track.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
    }
}

struct TrackPointDTO: Codable {
    let lat: Double
    let lon: Double
}

struct TrainingRecordInfo: Codable {
    let record_id: String
    let delta_state: Int
    let end_time: String
    let training_type: TrainingType
    let track: [TrackPointDTO]
}

struct TrainingRecordsResponse: Codable {
    let records: [TrainingRecordInfo]
}

enum TrainingType: String, Codable {
    case freeTraining = "freeTraining"
    case routeTraining = "routeTraining"
}
