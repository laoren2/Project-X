//
//  BikeEventModel.swift
//  sportsx
//
//  Created by 任杰 on 2025/3/14.
//

import Foundation
import CoreLocation


// 赛道数据结构
struct BikeTrack: Identifiable {
    var id: String { trackID }
    let trackID: String
    let name: String
    let startDate: Date
    let endDate: Date
    let from: CLLocationCoordinate2D
    let to: CLLocationCoordinate2D
    let image_url: String
    
    // 添加新的属性
    let elevationDifference: Int        // 海拔差(米)
    let regionName: String              // 覆盖的地理区域
    let fee: Int                        // 报名费
    let prizePool: Int                  // 奖金池金额
    var totalParticipants: Int = 0      // 总参与人数
    var currentParticipants: Int = 0    // 当前参与人数
    
    init(from track: BikeTrackInfoDTO) {
        self.trackID = track.track_id
        self.name = track.name
        self.startDate = ISO8601DateFormatter().date(from: track.start_date) ?? Date()
        self.endDate = ISO8601DateFormatter().date(from: track.end_date) ?? Date()
        self.from = CLLocationCoordinate2D(latitude: track.from_latitude, longitude: track.from_longitude)
        self.to = CLLocationCoordinate2D(latitude: track.to_latitude, longitude: track.to_longitude)
        self.image_url = track.image_url
        self.elevationDifference = track.elevation_difference
        self.regionName = track.sub_region_name
        self.fee = track.fee
        self.prizePool = track.prize_pool
    }
}

// 赛事数据结构
struct BikeEvent: Identifiable {
    var id: String { eventID }
    let eventID: String
    let name: String
    let description: String
    let startDate: Date         // 赛事的开始时间
    let endDate: Date           // 赛事的结束时间
    let image_url: String
    var tracks: [BikeTrack] = []    // 修改为可变属性
    
    init(from event: BikeEventInfoDTO) {
        self.eventID = event.event_id
        self.name = event.name
        self.description = event.description
        self.startDate = ISO8601DateFormatter().date(from: event.start_date) ?? Date()
        self.endDate = ISO8601DateFormatter().date(from: event.end_date) ?? Date()
        self.image_url = event.image_url
    }
}

struct BikeEventInfoDTO: Codable {
    let event_id: String
    let name: String
    let description: String
    let start_date: String
    let end_date: String
    let image_url: String
}

struct BikeEventsResponse: Codable {
    let events: [BikeEventInfoDTO]
}

struct BikeTrackInfoDTO: Codable {
    let track_id: String
    let name: String
    
    let start_date: String
    let end_date: String
    let image_url: String
    
    let from_latitude: Double
    let from_longitude: Double
    let to_latitude: Double
    let to_longitude: Double
    let elevation_difference: Int    // 海拔差(米)
    let sub_region_name: String      // 覆盖的地理子区域
    let fee: Int                     // 报名费
    let prize_pool: Int              // 奖金池金额
}

struct BikeTracksResponse: Codable {
    let tracks: [BikeTrackInfoDTO]
}
