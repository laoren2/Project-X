//
//  AdminViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2025/6/3.
//
import Foundation
import UIKit
import _PhotosUI_SwiftUI


class EventBackendViewModel: ObservableObject {
    @Published var events: [EventCardEntry] = []
    @Published var showCreateSheet = false
    @Published var showUpdateSheet = false
    
    var hasMoreEvents: Bool = true
    var currentPage: Int = 1
    
    var selectedEventID: String = ""
    
    // 更新的event信息
    @Published var name: String = ""
    @Published var description: String = ""
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Date().addingTimeInterval(3600*24)
    var image_url: String = ""
}

enum SportType: String, CaseIterable, Codable {
    case running
    case bike
    
    var displayName: String {
        switch self {
        case .running: return "跑步"
        case .bike: return "自行车"
        }
    }
}

struct EventCardEntry: Identifiable, Equatable {
    let id: UUID
    let event_id: String
    let name: String
    let description: String
    let start_date: String
    let end_date: String
    let season_name: String
    let region_name: String
    let sport_type: SportType
    let image_url: String
    
    init(from event: EventInfoDTO) {
        self.id = UUID()
        self.event_id = event.event_id
        self.name = event.name
        self.description = event.description
        self.start_date = event.start_date
        self.end_date = event.end_date
        self.season_name = event.season_name
        self.region_name = event.region_name
        self.sport_type = event.sport_type
        self.image_url = event.image_url
    }
    
    static func == (lhs: EventCardEntry, rhs: EventCardEntry) -> Bool {
        return lhs.event_id == rhs.event_id
    }
}

struct EventInfoDTO: Codable {
    let event_id: String
    let name: String
    let description: String
    let start_date: String
    let end_date: String
    let season_name: String
    let region_name: String
    let sport_type: SportType
    let image_url: String
}

struct EventsResponse: Codable {
    let events: [EventInfoDTO]
}

class TrackBackendViewModel: ObservableObject {
    @Published var tracks: [TrackCardEntry] = []
    @Published var showCreateSheet = false
    @Published var showUpdateSheet = false
    
    var hasMoreTracks: Bool = true
    var currentPage: Int = 1
    
    var selectedTrackID: String = ""
    
    // 更新的track信息
    @Published var name: String = ""
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Date().addingTimeInterval(3600*24)
    
    @Published var from_la: String = ""
    @Published var from_lo: String = ""
    @Published var to_la: String = ""
    @Published var to_lo: String = ""
    
    @Published var elevationDifference: String = ""
    @Published var subRegioName: String = ""
    @Published var fee: String = ""
    @Published var prizePool: String = ""
    
    var image_url: String = ""
}

struct TrackCardEntry: Identifiable, Equatable {
    let id: UUID
    let track_id: String
    let name: String
    let from_latitude: String
    let from_longitude: String
    let to_latitude: String
    let to_longitude: String
    
    let start_date: String
    let end_date: String
    let event_name: String
    let season_name: String
    let region_name: String
    let sport_type: SportType
    let image_url: String
    
    let elevationDifference: String    // 海拔差(米)
    let subRegioName: String        // 覆盖的地理子区域
    let fee: String                    // 报名费
    let prizePool: String              // 奖金池金额
    
    
    init(from track: TrackInfoDTO) {
        self.id = UUID()
        self.track_id = track.track_id
        self.name = track.name
        self.from_latitude = track.from_latitude
        self.from_longitude = track.from_longitude
        self.to_latitude = track.to_latitude
        self.to_longitude = track.to_longitude
        
        self.start_date = track.start_date
        self.end_date = track.end_date
        self.event_name = track.event_name
        self.season_name = track.season_name
        self.region_name = track.region_name
        self.sport_type = track.sport_type
        self.image_url = track.image_url
        
        self.elevationDifference = track.elevation_difference
        self.subRegioName = track.sub_region_name
        self.fee = track.fee
        self.prizePool = track.prize_pool
    }
    
    static func == (lhs: TrackCardEntry, rhs: TrackCardEntry) -> Bool {
        return lhs.track_id == rhs.track_id
    }
}

struct TrackInfoDTO: Codable {
    let track_id: String
    let name: String
    
    let start_date: String
    let end_date: String
    let event_name: String
    let season_name: String
    let region_name: String
    let sport_type: SportType
    let image_url: String
    
    let from_latitude: String
    let from_longitude: String
    let to_latitude: String
    let to_longitude: String
    let elevation_difference: String    // 海拔差(米)
    let sub_region_name: String         // 覆盖的地理子区域
    let fee: String                     // 报名费
    let prize_pool: String              // 奖金池金额
}

struct TracksResponse: Codable {
    let tracks: [TrackInfoDTO]
}
