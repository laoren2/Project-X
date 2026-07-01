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
    // 按活动段（segment）分组的缩略轨迹：段间为暂停缺口，绘制时各段独立不连线。
    let trackSegments: [[CLLocationCoordinate2D]]

    init(from record: TrainingRecordInfo) {
        self.record_id = record.record_id
        self.delta = record.delta_state
        self.endTime =  DateParser.parseISO8601(record.end_time)
        self.trainingType = record.training_type
        self.trackSegments = record.track.groupedBySegment()
    }
}

struct RunningFreeTrainingRecord: Identifiable {
    var id: String { record_id }
    let record_id: String
    let endTime: Date?
    let delta: Int
    let trainingType: TrainingType
    // 按活动段（segment）分组的缩略轨迹：段间为暂停缺口，绘制时各段独立不连线。
    let trackSegments: [[CLLocationCoordinate2D]]

    init(from record: TrainingRecordInfo) {
        self.record_id = record.record_id
        self.delta = record.delta_state
        self.endTime =  DateParser.parseISO8601(record.end_time)
        self.trainingType = record.training_type
        self.trackSegments = record.track.groupedBySegment()
    }
}

struct TrackPointDTO: Codable {
    let lat: Double
    let lon: Double
    // 活动段序号：free training 暂停恢复 +1；race/route 恒为 0。旧记录/旧服务端缺字段时默认 0。
    var segment: Int = 0
}

extension Array where Element == TrackPointDTO {
    /// 按 segment 把缩略轨迹点分组：相邻点 segment 不同即开启新段（暂停缺口）。
    func groupedBySegment() -> [[CLLocationCoordinate2D]] {
        var segments: [[CLLocationCoordinate2D]] = []
        var prevSegment: Int? = nil
        for p in self {
            let coord = CLLocationCoordinate2D(latitude: p.lat, longitude: p.lon)
            if p.segment == prevSegment, !segments.isEmpty {
                segments[segments.count - 1].append(coord)
            } else {
                segments.append([coord])
            }
            prevSegment = p.segment
        }
        return segments
    }
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
