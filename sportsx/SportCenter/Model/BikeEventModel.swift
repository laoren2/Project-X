//
//  BikeEventModel.swift
//  sportsx
//
//  Created by 任杰 on 2025/3/14.
//

import Foundation
import CoreLocation


// 自行车赛道地形类型
enum BikeTrackTerrainType: String, Codable {
    case road = "road"
    case crossCountry = "crossCountry"
    case enduro = "enduro"
    case downHill = "downHill"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .road:
            return "competition.terrain.road"
        case .crossCountry:
            return "competition.terrain.crossCountry"
        case .enduro:
            return "competition.terrain.enduro"
        case .downHill:
            return "competition.terrain.downHill"
        case .other:
            return "competition.terrain.other"
        }
    }
}

// 赛道数据结构
struct BikeTrack: Identifiable, Equatable {
    var id: String { trackID }
    let trackID: String
    let name: String
    let startDate: Date?
    let endDate: Date?
    let from: CLLocationCoordinate2D
    let fromRadius: Int
    let to: CLLocationCoordinate2D
    let toRadius: Int
    let image_url: String
    let terrainType: BikeTrackTerrainType
    let singleRegisterCardUrl: String
    let teamRegisterCardUrl: String
    
    // 添加新的属性
    let elevationDifference: Int        // 海拔差(米)
    let regionName: String              // 覆盖的地理区域
    let prizePool: Int                  // 奖金池金额
    let score: Int                      // 积分
    let totalParticipants: Int          // 总参与人数
    let distance: Double
    let currentParticipants: Int = 0        // 当前参与人数
    
    var rankInfo: BikeUserRankCard? = nil
    
    init(from track: BikeTrackInfoDTO) {
        self.trackID = track.track_id
        self.name = track.name
        self.startDate = ISO8601DateFormatter().date(from: track.start_date)
        self.endDate = ISO8601DateFormatter().date(from: track.end_date)
        self.from = CLLocationCoordinate2D(latitude: track.from_latitude, longitude: track.from_longitude)
        self.fromRadius = track.from_radius
        self.to = CLLocationCoordinate2D(latitude: track.to_latitude, longitude: track.to_longitude)
        self.toRadius = track.to_radius
        self.image_url = track.image_url
        self.terrainType = track.terrain_type
        self.singleRegisterCardUrl = track.single_register_card_url
        self.teamRegisterCardUrl = track.team_register_card_url
        self.elevationDifference = track.elevation_difference
        self.regionName = track.sub_region_name
        self.prizePool = track.prize_pool
        self.score = track.score
        self.distance = track.distance
        self.totalParticipants = track.totalParticipants
    }
    
    static func == (lhs: BikeTrack, rhs: BikeTrack) -> Bool {
        return lhs.trackID == rhs.trackID
    }
}

// 赛事数据结构
struct BikeEvent: Identifiable {
    var id: String { eventID }
    let eventID: String
    let name: String
    let description: String
    let startDate: Date?         // 赛事的开始时间
    let endDate: Date?           // 赛事的结束时间
    let image_url: String
    var tracks: [BikeTrack] = []    // 修改为可变属性
    
    init(from event: BikeEventInfoDTO) {
        self.eventID = event.event_id
        self.name = event.name
        self.description = event.description
        self.startDate = ISO8601DateFormatter().date(from: event.start_date)
        self.endDate = ISO8601DateFormatter().date(from: event.end_date)
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
    let terrain_type: BikeTrackTerrainType
    let single_register_card_url: String
    let team_register_card_url: String
    
    let from_latitude: Double
    let from_longitude: Double
    let from_radius: Int
    let to_latitude: Double
    let to_longitude: Double
    let to_radius: Int
    
    let elevation_difference: Int       // 海拔差(米)
    let sub_region_name: String         // 覆盖的地理子区域
    let prize_pool: Int                 // 奖金池金额
    let score: Int
    let distance: Double
    let totalParticipants: Int
}

struct BikeTracksResponse: Codable {
    let tracks: [BikeTrackInfoDTO]
}
