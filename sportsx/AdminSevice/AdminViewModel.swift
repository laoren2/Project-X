//
//  AdminViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2025/6/3.
//
import Foundation
import UIKit
import _PhotosUI_SwiftUI


class RunningEventBackendViewModel: ObservableObject {
    @Published var events: [RunningEventCardEntry] = []
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

struct RunningEventCardEntry: Identifiable, Equatable {
    let id: UUID
    let event_id: String
    let name: String
    let description: String
    let start_date: String
    let end_date: String
    let season_name: String
    let region_name: String
    let image_url: String
    
    init(from event: RunningEventInfoInternalDTO) {
        self.id = UUID()
        self.event_id = event.event_id
        self.name = event.name
        self.description = event.description
        self.start_date = event.start_date
        self.end_date = event.end_date
        self.season_name = event.season_name
        self.region_name = event.region_name
        self.image_url = event.image_url
    }
    
    static func == (lhs: RunningEventCardEntry, rhs: RunningEventCardEntry) -> Bool {
        return lhs.event_id == rhs.event_id
    }
}

struct RunningEventInfoInternalDTO: Codable {
    let event_id: String
    let name: String
    let description: String
    let start_date: String
    let end_date: String
    let season_name: String
    let region_name: String
    let image_url: String
}

struct RunningEventsInternalResponse: Codable {
    let events: [RunningEventInfoInternalDTO]
}

class RunningTrackBackendViewModel: ObservableObject {
    @Published var tracks: [RunningTrackCardEntry] = []
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
    @Published var prizePool: String = ""
    @Published var distance: String = ""
    @Published var score: String = ""
    
    var image_url: String = ""
}

struct RunningTrackCardEntry: Identifiable, Equatable {
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
    let image_url: String
    
    let elevationDifference: String    // 海拔差(米)
    let subRegioName: String        // 覆盖的地理子区域
    let prizePool: String              // 奖金池金额
    let distance: String
    let score: String              // 积分
    let is_settled: Bool
    
    init(from track: RunningTrackInfoInternalDTO) {
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
        self.image_url = track.image_url
        
        self.elevationDifference = track.elevation_difference
        self.subRegioName = track.sub_region_name
        self.prizePool = track.prize_pool
        self.distance = track.distance
        self.score = track.score
        self.is_settled = track.is_settled
    }
    
    static func == (lhs: RunningTrackCardEntry, rhs: RunningTrackCardEntry) -> Bool {
        return lhs.track_id == rhs.track_id
    }
}

struct RunningTrackInfoInternalDTO: Codable {
    let track_id: String
    let name: String
    
    let start_date: String
    let end_date: String
    let event_name: String
    let season_name: String
    let region_name: String
    let image_url: String
    
    let from_latitude: String
    let from_longitude: String
    let to_latitude: String
    let to_longitude: String
    let elevation_difference: String    // 海拔差(米)
    let sub_region_name: String         // 覆盖的地理子区域
    let prize_pool: String              // 奖金池金额
    let distance: String
    let score: String
    let is_settled: Bool                // 是否已结算
}

struct RunningTracksInternalResponse: Codable {
    let tracks: [RunningTrackInfoInternalDTO]
}


class BikeEventBackendViewModel: ObservableObject {
    @Published var events: [BikeEventCardEntry] = []
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

struct BikeEventCardEntry: Identifiable, Equatable {
    let id: UUID
    let event_id: String
    let name: String
    let description: String
    let start_date: String
    let end_date: String
    let season_name: String
    let region_name: String
    let image_url: String
    
    init(from event: BikeEventInfoInternalDTO) {
        self.id = UUID()
        self.event_id = event.event_id
        self.name = event.name
        self.description = event.description
        self.start_date = event.start_date
        self.end_date = event.end_date
        self.season_name = event.season_name
        self.region_name = event.region_name
        self.image_url = event.image_url
    }
    
    static func == (lhs: BikeEventCardEntry, rhs: BikeEventCardEntry) -> Bool {
        return lhs.event_id == rhs.event_id
    }
}

struct BikeEventInfoInternalDTO: Codable {
    let event_id: String
    let name: String
    let description: String
    let start_date: String
    let end_date: String
    let season_name: String
    let region_name: String
    let image_url: String
}

struct BikeEventsInternalResponse: Codable {
    let events: [BikeEventInfoInternalDTO]
}

class BikeTrackBackendViewModel: ObservableObject {
    @Published var tracks: [BikeTrackCardEntry] = []
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
    @Published var prizePool: String = ""
    @Published var score: String = ""
    
    var image_url: String = ""
}

struct BikeTrackCardEntry: Identifiable, Equatable {
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
    let image_url: String
    
    let elevationDifference: String    // 海拔差(米)
    let subRegioName: String        // 覆盖的地理子区域
    let prizePool: String              // 奖金池金额
    let score: String              // 积分
    let is_settled: Bool
    
    init(from track: BikeTrackInfoInternalDTO) {
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
        self.image_url = track.image_url
        
        self.elevationDifference = track.elevation_difference
        self.subRegioName = track.sub_region_name
        self.prizePool = track.prize_pool
        self.score = track.score
        self.is_settled = track.is_settled
    }
    
    static func == (lhs: BikeTrackCardEntry, rhs: BikeTrackCardEntry) -> Bool {
        return lhs.track_id == rhs.track_id
    }
}

struct BikeTrackInfoInternalDTO: Codable {
    let track_id: String
    let name: String
    
    let start_date: String
    let end_date: String
    let event_name: String
    let season_name: String
    let region_name: String
    let image_url: String
    
    let from_latitude: String
    let from_longitude: String
    let to_latitude: String
    let to_longitude: String
    let elevation_difference: String    // 海拔差(米)
    let sub_region_name: String         // 覆盖的地理子区域
    let prize_pool: String              // 奖金池金额
    let score: String
    let is_settled: Bool                // 是否已结算
}

struct BikeTracksInternalResponse: Codable {
    let tracks: [BikeTrackInfoInternalDTO]
}


class CPAssetBackendViewModel: ObservableObject {
    @Published var assets: [CPAssetCardEntry] = []
    @Published var showCreateSheet = false
    @Published var showUpdateSheet = false
    
    var hasMoreEvents: Bool = true
    var currentPage: Int = 1
    
    var selectedAssetID: String = ""
    
    // 更新的asset信息
    @Published var name: String = ""
    @Published var description: String = ""
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Date().addingTimeInterval(3600*24)
    var image_url: String = ""
}

struct CPAssetCardEntry: Identifiable, Equatable {
    var id: String {asset_id}
    let asset_id: String
    let cpasset_type: String
    let name: String
    let description: String
    let image_url: String
    
    init(from asset: CPAssetDefDTO) {
        self.asset_id = asset.asset_id
        self.cpasset_type = asset.cpasset_type
        self.name = asset.name
        self.description = asset.description
        self.image_url = asset.image_url
    }
    
    static func == (lhs: CPAssetCardEntry, rhs: CPAssetCardEntry) -> Bool {
        return lhs.asset_id == rhs.asset_id
    }
}

struct CPAssetDefDTO: Codable {
    let asset_id: String
    let cpasset_type: String
    let name: String
    let description: String
    let image_url: String
}

struct CPAssetInternalResponse: Codable {
    let defs: [CPAssetDefDTO]
}


class CPAssetPriceBackendViewModel: ObservableObject {
    @Published var assets: [CPAssetPriceCardEntry] = []
    @Published var showCreateSheet = false
    @Published var showUpdateSheet = false
    
    var hasMoreEvents: Bool = true
    var currentPage: Int = 1
    
    var selectedAssetID: String = ""
    
    // 更新的asset信息
    @Published var name: String = ""
    @Published var description: String = ""
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Date().addingTimeInterval(3600*24)
    var image_url: String = ""
}

struct CPAssetPriceCardEntry: Identifiable, Equatable {
    var id: String {asset_id}
    let asset_id: String
    let name: String
    let description: String
    let image_url: String
    let ccasset_type: CCAssetType
    let price: Int
    let is_on_shelves: Bool
    
    init(from asset: CPAssetPriceDTO) {
        self.asset_id = asset.asset_id
        self.name = asset.name
        self.description = asset.description
        self.image_url = asset.image_url
        self.ccasset_type = asset.ccasset_type
        self.price = asset.price
        self.is_on_shelves = asset.is_on_shelves
    }
    
    static func == (lhs: CPAssetPriceCardEntry, rhs: CPAssetPriceCardEntry) -> Bool {
        return lhs.asset_id == rhs.asset_id
    }
}

struct CPAssetPriceDTO: Codable {
    let asset_id: String
    let name: String
    let description: String
    let image_url: String
    let ccasset_type: CCAssetType
    let price: Int
    let is_on_shelves: Bool
}

struct CPAssetPriceInternalResponse: Codable {
    let assets: [CPAssetPriceDTO]
}

class MagicCardBackendViewModel: ObservableObject {
    @Published var cards: [MagicCardEntry] = []
    @Published var showCreateSheet = false
    @Published var showUpdateSheet = false
    
    var hasMoreEvents: Bool = true
    var currentPage: Int = 1
    
    var selectedCardID: String = ""
    
    // 更新的asset信息
    @Published var name: String = ""
    @Published var description: String = ""
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Date().addingTimeInterval(3600*24)
    var image_url: String = ""
}

struct MagicCardEntry: Identifiable, Equatable {
    var id: String {def_id}
    let def_id: String
    let sport_type: SportName
    let name: String
    let description: String
    let image_url: String
    let rarity: String
    
    init(from card: MagicCardDefDTO) {
        self.def_id = card.def_id
        self.name = card.name
        self.image_url = card.image_url
        self.sport_type = card.sport_type
        self.rarity = card.rarity
        self.description = card.description
    }
    
    static func == (lhs: MagicCardEntry, rhs: MagicCardEntry) -> Bool {
        return lhs.def_id == rhs.def_id
    }
}

struct MagicCardDefDTO: Codable {
    let def_id: String
    let name: String
    let image_url: String
    let sport_type: SportName
    let rarity: String
    let description: String
    let skill1_description: String?
    let skill2_description: String?
    let skill3_description: String?
    let version: String
    let type_name: String
    let tags: [String]
    let effect_config: JSONValue
}

struct MagicCardInternalResponse: Codable {
    let defs: [MagicCardDefDTO]
}

class MagicCardPriceBackendViewModel: ObservableObject {
    @Published var cards: [MagicCardPriceCardEntry] = []
    @Published var showCreateSheet = false
    @Published var showUpdateSheet = false
    
    var hasMoreEvents: Bool = true
    var currentPage: Int = 1
    
    var selectedCardID: String = ""
    
    // 更新的card信息
    @Published var name: String = ""
    @Published var description: String = ""
    var image_url: String = ""
}

struct MagicCardPriceCardEntry: Identifiable, Equatable {
    var id: String {def_id}
    let def_id: String
    let name: String
    let image_url: String
    let ccasset_type: CCAssetType
    let price: Int
    let is_on_shelves: Bool
    
    init(from card: MagicCardPriceDTO) {
        self.def_id = card.def_id
        self.name = card.name
        self.image_url = card.image_url
        self.ccasset_type = card.ccasset_type
        self.price = card.price
        self.is_on_shelves = card.is_on_shelves
    }
    
    static func == (lhs: MagicCardPriceCardEntry, rhs: MagicCardPriceCardEntry) -> Bool {
        return lhs.def_id == rhs.def_id
    }
}

struct MagicCardPriceDTO: Codable {
    let def_id: String
    let name: String
    let image_url: String
    let sport_type: SportName
    let rarity: String
    let description: String
    let skill1_description: String?
    let skill2_description: String?
    let skill3_description: String?
    let version: String
    let effect_config: JSONValue
    
    let ccasset_type: CCAssetType
    let price: Int
    let is_on_shelves: Bool
}

struct MagicCardPriceInternalResponse: Codable {
    let cards: [MagicCardPriceDTO]
}
