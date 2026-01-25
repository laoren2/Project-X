//
//  AdminViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2025/6/3.
//

#if DEBUG
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
    @Published var name_en: String = ""
    @Published var name_hans: String = ""
    @Published var name_hant: String = ""
    @Published var description_en: String = ""
    @Published var description_hans: String = ""
    @Published var description_hant: String = ""
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Date().addingTimeInterval(3600*24)
    var image_url: String = ""
}

struct RunningEventCardEntry: Identifiable, Equatable {
    let id: UUID
    let event_id: String
    let name_en: String
    let name_hans: String
    let name_hant: String
    let description_en: String
    let description_hans: String
    let description_hant: String
    let start_date: String
    let end_date: String
    let season_name: String
    let region_name: String
    let image_url: String
    
    init(from event: RunningEventInfoInternalDTO) {
        self.id = UUID()
        self.event_id = event.event_id
        self.name_en = event.name["en"]?.stringValue ?? "空"
        self.name_hans = event.name["zh-Hans"]?.stringValue ?? "空"
        self.name_hant = event.name["zh-Hant"]?.stringValue ?? "空"
        self.description_en = event.description["en"]?.stringValue ?? "空"
        self.description_hans = event.description["zh-Hans"]?.stringValue ?? "空"
        self.description_hant = event.description["zh-Hant"]?.stringValue ?? "空"
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
    let name: JSONValue
    let description: JSONValue
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
    @Published var name_en: String = ""
    @Published var name_hans: String = ""
    @Published var name_hant: String = ""
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Date().addingTimeInterval(3600*24)
    
    @Published var from_la: String = ""
    @Published var from_lo: String = ""
    @Published var from_radius: Int = 0
    @Published var to_la: String = ""
    @Published var to_lo: String = ""
    @Published var to_radius: Int = 0
    
    @Published var elevationDifference: String = ""
    @Published var subRegioName_en: String = ""
    @Published var subRegioName_hans: String = ""
    @Published var subRegioName_hant: String = ""
    @Published var prizePool: String = ""
    @Published var distance: String = ""
    @Published var score: String = ""
    @Published var terrainType: RunningTrackTerrainType = .other
    
    var image_url: String = ""
}

struct RunningTrackCardEntry: Identifiable, Equatable {
    let id: UUID
    let track_id: String
    let name_en: String
    let name_hans: String
    let name_hant: String
    let from_latitude: String
    let from_longitude: String
    let from_radius: Int
    let to_latitude: String
    let to_longitude: String
    let to_radius: Int
    
    let start_date: String
    let end_date: String
    let event_name: String
    let season_name: String
    let region_name: String
    let image_url: String
    
    let elevationDifference: String     // 海拔差(米)
    let subRegioName_en: String            // 覆盖的地理子区域
    let subRegioName_hans: String
    let subRegioName_hant: String
    let prizePool: String               // 奖金池金额
    let distance: String
    let score: String                   // 积分
    let terrain_type: RunningTrackTerrainType
    let is_settled: Bool
    
    init(from track: RunningTrackInfoInternalDTO) {
        self.id = UUID()
        self.track_id = track.track_id
        self.name_en = track.name["en"]?.stringValue ?? "空"
        self.name_hans = track.name["zh-Hans"]?.stringValue ?? "空"
        self.name_hant = track.name["zh-Hant"]?.stringValue ?? "空"
        self.from_latitude = track.from_latitude
        self.from_longitude = track.from_longitude
        self.from_radius = track.from_radius
        self.to_latitude = track.to_latitude
        self.to_longitude = track.to_longitude
        self.to_radius = track.to_radius
        
        self.start_date = track.start_date
        self.end_date = track.end_date
        self.event_name = track.event_name
        self.season_name = track.season_name
        self.region_name = track.region_name
        self.image_url = track.image_url
        self.terrain_type = track.terrain_type
        
        self.elevationDifference = track.elevation_difference
        self.subRegioName_en = track.sub_region_name["en"]?.stringValue ?? "空"
        self.subRegioName_hans = track.sub_region_name["zh-Hans"]?.stringValue ?? "空"
        self.subRegioName_hant = track.sub_region_name["zh-Hant"]?.stringValue ?? "空"
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
    let name: JSONValue
    
    let start_date: String
    let end_date: String
    let event_name: String
    let season_name: String
    let region_name: String
    let image_url: String
    
    let from_latitude: String
    let from_longitude: String
    let from_radius: Int
    let to_latitude: String
    let to_longitude: String
    let to_radius: Int
    let elevation_difference: String    // 海拔差(米)
    let sub_region_name: JSONValue         // 覆盖的地理子区域
    let prize_pool: String              // 奖金池金额
    let distance: String
    let score: String
    let terrain_type: RunningTrackTerrainType  // 地形类型
    let is_settled: Bool                // 是否已结算
}

struct RunningTracksInternalResponse: Codable {
    let tracks: [RunningTrackInfoInternalDTO]
}

class RunningRecordBackendViewModel: ObservableObject {
    @Published var records: [RunningUnverifiedRecordInfo] = []
    @Published var isLoading: Bool = false
    
    @Published var selectedRecord: RunningUnverifiedRecordInfo?
    
    var hasMoreRecords: Bool = true
    var currentPage: Int = 1
    var pageSize: Int = 10
    
    func queryRecords() {
        isLoading = true
        guard var components = URLComponents(string: "/competition/running/query_unverified_records") else { return }
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(currentPage)"),
            URLQueryItem(name: "size", value: "\(pageSize)")
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .get, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: RunningUnverifiedRecordResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            DispatchQueue.main.async {
                self.isLoading = false
            }
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        for record in unwrappedData.records {
                            self.records.append(RunningUnverifiedRecordInfo(from: record))
                        }
                    }
                    if unwrappedData.records.count < self.pageSize {
                        self.hasMoreRecords = false
                    } else {
                        self.hasMoreRecords = true
                        self.currentPage += 1
                    }
                }
            default: break
            }
        }
    }
    
    func handleVerify(recordID: String, result: Bool) {
        guard var components = URLComponents(string: "/competition/running/handle_unverified_record") else { return }
        components.queryItems = [
            URLQueryItem(name: "record_id", value: recordID),
            URLQueryItem(name: "result", value: "\(result)")
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .post, isInternal: true)
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    if let index = self.records.firstIndex(where: { $0.record_id == recordID }) {
                        self.records.remove(at: index)
                    }
                default: break
                }
                self.selectedRecord = nil
            }
        }
    }
}

struct RunningUnverifiedRecordInfo: Identifiable, Equatable {
    let id: UUID
    let is_vip: Bool
    let record_id: String
    let validation_score: Double?
    let basePath: [PathPoint]
    let path: [RunningPathPoint]
    let samplePath: [RunningSamplePathPoint]
    let finished_at: Date?
    
    init(from record: RunningUnverifiedRecordDTO) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        id = UUID()
        is_vip = record.is_vip
        record_id = record.record_id
        validation_score = record.validation_score
        path = record.path
        basePath = record.path.map { $0.base }
        samplePath = RunningPathPointTool.computeSamplePoints(pathData: record.path)
        if let finishedTime = record.finished_at {
            finished_at = formatter.date(from: finishedTime)
        } else {
            finished_at = nil
        }
    }
    
    static func == (lhs: RunningUnverifiedRecordInfo, rhs: RunningUnverifiedRecordInfo) -> Bool {
        return lhs.record_id == rhs.record_id
    }
}

struct RunningUnverifiedRecordDTO: Codable {
    let is_vip: Bool
    let record_id: String
    let validation_score: Double?
    let path: [RunningPathPoint]
    let finished_at: String?
}

struct RunningUnverifiedRecordResponse: Codable {
    let records: [RunningUnverifiedRecordDTO]
}


class BikeEventBackendViewModel: ObservableObject {
    @Published var events: [BikeEventCardEntry] = []
    @Published var showCreateSheet = false
    @Published var showUpdateSheet = false
    
    var hasMoreEvents: Bool = true
    var currentPage: Int = 1
    
    var selectedEventID: String = ""
    
    // 更新的event信息
    @Published var name_en: String = ""
    @Published var name_hans: String = ""
    @Published var name_hant: String = ""
    @Published var description_en: String = ""
    @Published var description_hans: String = ""
    @Published var description_hant: String = ""
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Date().addingTimeInterval(3600*24)
    var image_url: String = ""
}

struct BikeEventCardEntry: Identifiable, Equatable {
    let id: UUID
    let event_id: String
    let name_en: String
    let name_hans: String
    let name_hant: String
    let description_en: String
    let description_hans: String
    let description_hant: String
    let start_date: String
    let end_date: String
    let season_name: String
    let region_name: String
    let image_url: String
    
    init(from event: BikeEventInfoInternalDTO) {
        self.id = UUID()
        self.event_id = event.event_id
        self.name_en = event.name["en"]?.stringValue ?? "空"
        self.name_hans = event.name["zh-Hans"]?.stringValue ?? "空"
        self.name_hant = event.name["zh-Hant"]?.stringValue ?? "空"
        self.description_en = event.description["en"]?.stringValue ?? "空"
        self.description_hans = event.description["zh-Hans"]?.stringValue ?? "空"
        self.description_hant = event.description["zh-Hant"]?.stringValue ?? "空"
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
    let name: JSONValue
    let description: JSONValue
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
    @Published var name_en: String = ""
    @Published var name_hans: String = ""
    @Published var name_hant: String = ""
    
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Date().addingTimeInterval(3600*24)
    
    @Published var from_la: String = ""
    @Published var from_lo: String = ""
    @Published var from_radius: Int = 0
    @Published var to_la: String = ""
    @Published var to_lo: String = ""
    @Published var to_radius: Int = 0
    
    @Published var elevationDifference: String = ""
    @Published var subRegioName_en: String = ""
    @Published var subRegioName_hans: String = ""
    @Published var subRegioName_hant: String = ""
    @Published var prizePool: String = ""
    @Published var score: String = ""
    @Published var distance: String = ""
    @Published var terrainType: BikeTrackTerrainType = .other
    
    var image_url: String = ""
}

struct BikeTrackCardEntry: Identifiable, Equatable {
    let id: UUID
    let track_id: String
    let name_en: String
    let name_hans: String
    let name_hant: String
    let from_latitude: String
    let from_longitude: String
    let from_radius: Int
    let to_latitude: String
    let to_longitude: String
    let to_radius: Int
    
    let start_date: String
    let end_date: String
    let event_name: String
    let season_name: String
    let region_name: String
    let image_url: String
    
    let elevationDifference: String     // 海拔差(米)
    let subRegioName_en: String            // 覆盖的地理子区域
    let subRegioName_hans: String
    let subRegioName_hant: String
    let prizePool: String               // 奖金池金额
    let score: String                   // 积分
    let distance: String
    let terrain_type: BikeTrackTerrainType
    let is_settled: Bool
    
    init(from track: BikeTrackInfoInternalDTO) {
        self.id = UUID()
        self.track_id = track.track_id
        self.name_en = track.name["en"]?.stringValue ?? "空"
        self.name_hans = track.name["zh-Hans"]?.stringValue ?? "空"
        self.name_hant = track.name["zh-Hant"]?.stringValue ?? "空"
        self.from_latitude = track.from_latitude
        self.from_longitude = track.from_longitude
        self.from_radius = track.from_radius
        self.to_latitude = track.to_latitude
        self.to_longitude = track.to_longitude
        self.to_radius = track.to_radius
        
        self.start_date = track.start_date
        self.end_date = track.end_date
        self.event_name = track.event_name
        self.season_name = track.season_name
        self.region_name = track.region_name
        self.image_url = track.image_url
        
        self.elevationDifference = track.elevation_difference
        self.subRegioName_en = track.sub_region_name["en"]?.stringValue ?? "空"
        self.subRegioName_hans = track.sub_region_name["zh-Hans"]?.stringValue ?? "空"
        self.subRegioName_hant = track.sub_region_name["zh-Hant"]?.stringValue ?? "空"
        self.prizePool = track.prize_pool
        self.score = track.score
        self.terrain_type = track.terrain_type
        self.distance = track.distance
        self.is_settled = track.is_settled
    }
    
    static func == (lhs: BikeTrackCardEntry, rhs: BikeTrackCardEntry) -> Bool {
        return lhs.track_id == rhs.track_id
    }
}

struct BikeTrackInfoInternalDTO: Codable {
    let track_id: String
    let name: JSONValue
    
    let start_date: String
    let end_date: String
    let event_name: String
    let season_name: String
    let region_name: String
    let image_url: String
    
    let from_latitude: String
    let from_longitude: String
    let from_radius: Int
    let to_latitude: String
    let to_longitude: String
    let to_radius: Int
    
    let elevation_difference: String    // 海拔差(米)
    let sub_region_name: JSONValue         // 覆盖的地理子区域
    let prize_pool: String              // 奖金池金额
    let score: String                   // 积分等级
    let distance: String
    let terrain_type: BikeTrackTerrainType  // 地形类型
    let is_settled: Bool                // 是否已结算
}

struct BikeTracksInternalResponse: Codable {
    let tracks: [BikeTrackInfoInternalDTO]
}

class BikeRecordBackendViewModel: ObservableObject {
    @Published var records: [BikeUnverifiedRecordInfo] = []
    @Published var isLoading: Bool = false
    
    @Published var selectedRecord: BikeUnverifiedRecordInfo?
    
    var hasMoreRecords: Bool = true
    var currentPage: Int = 1
    var pageSize: Int = 10
    
    func queryRecords() {
        isLoading = true
        guard var components = URLComponents(string: "/competition/bike/query_unverified_records") else { return }
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(currentPage)"),
            URLQueryItem(name: "size", value: "\(pageSize)")
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .get, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: BikeUnverifiedRecordResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            DispatchQueue.main.async {
                self.isLoading = false
            }
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        for record in unwrappedData.records {
                            self.records.append(BikeUnverifiedRecordInfo(from: record))
                        }
                    }
                    if unwrappedData.records.count < self.pageSize {
                        self.hasMoreRecords = false
                    } else {
                        self.hasMoreRecords = true
                        self.currentPage += 1
                    }
                }
            default: break
            }
        }
    }
    
    func handleVerify(recordID: String, result: Bool) {
        guard var components = URLComponents(string: "/competition/bike/handle_unverified_record") else { return }
        components.queryItems = [
            URLQueryItem(name: "record_id", value: recordID),
            URLQueryItem(name: "result", value: "\(result)")
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .post, isInternal: true)
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    if let index = self.records.firstIndex(where: { $0.record_id == recordID }) {
                        self.records.remove(at: index)
                    }
                default: break
                }
                self.selectedRecord = nil
            }
        }
    }
}

struct BikeUnverifiedRecordInfo: Identifiable, Equatable {
    let id: UUID
    let is_vip: Bool
    let record_id: String
    let validation_score: Double?
    let basePath: [PathPoint]
    let path: [BikePathPoint]
    let samplePath: [BikeSamplePathPoint]
    let finished_at: Date?
    
    init(from record: BikeUnverifiedRecordDTO) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        id = UUID()
        is_vip = record.is_vip
        record_id = record.record_id
        validation_score = record.validation_score
        path = record.path
        basePath = record.path.map { $0.base }
        samplePath = BikePathPointTool.computeSamplePoints(pathData: record.path)
        if let finishedTime = record.finished_at {
            finished_at = formatter.date(from: finishedTime)
        } else {
            finished_at = nil
        }
    }
    
    static func == (lhs: BikeUnverifiedRecordInfo, rhs: BikeUnverifiedRecordInfo) -> Bool {
        return lhs.record_id == rhs.record_id
    }
}

struct BikeUnverifiedRecordDTO: Codable {
    let is_vip: Bool
    let record_id: String
    let validation_score: Double?
    let path: [BikePathPoint]
    let finished_at: String?
}

struct BikeUnverifiedRecordResponse: Codable {
    let records: [BikeUnverifiedRecordDTO]
}


class CPAssetBackendViewModel: ObservableObject {
    @Published var assets: [CPAssetCardEntry] = []
    @Published var showCreateSheet = false
    @Published var showUpdateSheet = false
    
    var hasMoreEvents: Bool = true
    var currentPage: Int = 1
    
    var selectedAssetID: String = ""
    
    // 更新的asset信息
    @Published var name_en: String = ""
    @Published var name_hans: String = ""
    @Published var name_hant: String = ""
    @Published var description_en: String = ""
    @Published var description_hans: String = ""
    @Published var description_hant: String = ""
    var image_url: String = ""
}

struct CPAssetCardEntry: Identifiable, Equatable {
    var id: String {asset_id}
    let asset_id: String
    let cpasset_type: String
    let name_en: String
    let name_hans: String
    let name_hant: String
    let description_en: String
    let description_hans: String
    let description_hant: String
    let image_url: String
    
    init(from asset: CPAssetDefDTO) {
        self.asset_id = asset.asset_id
        self.cpasset_type = asset.cpasset_type
        self.name_en = asset.name["en"]?.stringValue ?? "空"
        self.name_hans = asset.name["zh-Hans"]?.stringValue ?? "空"
        self.name_hant = asset.name["zh-Hant"]?.stringValue ?? "空"
        self.description_en = asset.description["en"]?.stringValue ?? "空"
        self.description_hans = asset.description["zh-Hans"]?.stringValue ?? "空"
        self.description_hant = asset.description["zh-Hant"]?.stringValue ?? "空"
        self.image_url = asset.image_url
    }
    
    static func == (lhs: CPAssetCardEntry, rhs: CPAssetCardEntry) -> Bool {
        return lhs.asset_id == rhs.asset_id
    }
}

struct CPAssetDefDTO: Codable {
    let asset_id: String
    let cpasset_type: String
    let name: JSONValue
    let description: JSONValue
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
    let name_en: String
    let name_hans: String
    let name_hant: String
    let description_en: String
    let description_hans: String
    let description_hant: String
    let image_url: String
    let ccasset_type: CCAssetType
    let price: Int
    let is_on_shelves: Bool
    
    init(from asset: CPAssetPriceDTO) {
        self.asset_id = asset.asset_id
        self.name_en = asset.name["en"]?.stringValue ?? "空"
        self.name_hans = asset.name["zh-Hans"]?.stringValue ?? "空"
        self.name_hant = asset.name["zh-Hant"]?.stringValue ?? "空"
        self.description_en = asset.description["en"]?.stringValue ?? "空"
        self.description_hans = asset.description["zh-Hans"]?.stringValue ?? "空"
        self.description_hant = asset.description["zh-Hant"]?.stringValue ?? "空"
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
    let name: JSONValue
    let description: JSONValue
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
    @Published var name_en: String = ""
    @Published var name_hans: String = ""
    @Published var name_hant: String = ""
    @Published var description_en: String = ""
    @Published var description_hans: String = ""
    @Published var description_hant: String = ""
    @Published var skill1_description_en: String = ""
    @Published var skill1_description_hans: String = ""
    @Published var skill1_description_hant: String = ""
    @Published var skill2_description_en: String = ""
    @Published var skill2_description_hans: String = ""
    @Published var skill2_description_hant: String = ""
    @Published var skill3_description_en: String = ""
    @Published var skill3_description_hans: String = ""
    @Published var skill3_description_hant: String = ""
    var image_url: String = ""
    @Published var version: String = ""
}

struct MagicCardEntry: Identifiable, Equatable {
    var id: String {def_id}
    let def_id: String
    let sport_type: SportName
    let name_en: String
    let name_hans: String
    let name_hant: String
    let description_en: String
    let description_hans: String
    let description_hant: String
    let skill1_description_en: String
    let skill1_description_hans: String
    let skill1_description_hant: String
    let skill2_description_en: String
    let skill2_description_hans: String
    let skill2_description_hant: String
    let skill3_description_en: String
    let skill3_description_hans: String
    let skill3_description_hant: String
    let image_url: String
    let version: String
    let rarity: String
    
    init(from card: MagicCardDefDTO) {
        self.def_id = card.def_id
        self.name_en = card.name_i18n["en"]?.stringValue ?? "空"
        self.name_hans = card.name_i18n["zh-Hans"]?.stringValue ?? "空"
        self.name_hant = card.name_i18n["zh-Hant"]?.stringValue ?? "空"
        self.description_en = card.description_i18n["en"]?.stringValue ?? "空"
        self.description_hans = card.description_i18n["zh-Hans"]?.stringValue ?? "空"
        self.description_hant = card.description_i18n["zh-Hant"]?.stringValue ?? "空"
        if let skill1_des = card.skill1_description_i18n {
            self.skill1_description_en = skill1_des["en"]?.stringValue ?? ""
            self.skill1_description_hans = skill1_des["zh-Hans"]?.stringValue ?? ""
            self.skill1_description_hant = skill1_des["zh-Hant"]?.stringValue ?? ""
        } else {
            self.skill1_description_en = ""
            self.skill1_description_hans = ""
            self.skill1_description_hant = ""
        }
        if let skill2_des = card.skill2_description_i18n {
            self.skill2_description_en = skill2_des["en"]?.stringValue ?? ""
            self.skill2_description_hans = skill2_des["zh-Hans"]?.stringValue ?? ""
            self.skill2_description_hant = skill2_des["zh-Hant"]?.stringValue ?? ""
        } else {
            self.skill2_description_en = ""
            self.skill2_description_hans = ""
            self.skill2_description_hant = ""
        }
        if let skill3_des = card.skill3_description_i18n {
            self.skill3_description_en = skill3_des["en"]?.stringValue ?? ""
            self.skill3_description_hans = skill3_des["zh-Hans"]?.stringValue ?? ""
            self.skill3_description_hant = skill3_des["zh-Hant"]?.stringValue ?? ""
        } else {
            self.skill3_description_en = ""
            self.skill3_description_hans = ""
            self.skill3_description_hant = ""
        }
        self.image_url = card.image_url
        self.sport_type = card.sport_type
        self.rarity = card.rarity
        self.version = card.version
    }
    
    static func == (lhs: MagicCardEntry, rhs: MagicCardEntry) -> Bool {
        return lhs.def_id == rhs.def_id
    }
}

struct MagicCardDefDTO: Codable {
    let def_id: String
    let name_i18n: JSONValue
    let image_url: String
    let sport_type: SportName
    let rarity: String
    let description_i18n: JSONValue
    let skill1_description_i18n: JSONValue?
    let skill2_description_i18n: JSONValue?
    let skill3_description_i18n: JSONValue?
    let version: String
    //let type_name: String
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
    let name_en: String
    let name_hans: String
    let name_hant: String
    let image_url: String
    let ccasset_type: CCAssetType
    let price: Int
    let is_on_shelves: Bool
    
    init(from card: MagicCardPriceDTO) {
        self.def_id = card.def_id
        self.name_en = card.name["en"]?.stringValue ?? "空"
        self.name_hans = card.name["zh-Hans"]?.stringValue ?? "空"
        self.name_hant = card.name["zh-Hant"]?.stringValue ?? "空"
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
    let name: JSONValue
    let image_url: String
    let sport_type: SportName
    let rarity: String
    let description: JSONValue
    let skill1_description: JSONValue?
    let skill2_description: JSONValue?
    let skill3_description: JSONValue?
    let version: String
    let effect_config: JSONValue
    
    let ccasset_type: CCAssetType
    let price: Int
    let is_on_shelves: Bool
}

struct MagicCardPriceInternalResponse: Codable {
    let cards: [MagicCardPriceDTO]
}

class FeedbackMailBackendViewModel: ObservableObject {
    @Published var mails: [FeedbackMailInfo] = []
    @Published var isLoading: Bool = false
    @Published var selectedMail: FeedbackMailInfo?
    @Published var showMailDetail: Bool = false
    var hasMoreMails: Bool = true
    var currentPage: Int = 1
    var pageSize: Int = 10
    
    func queryMails() {
        isLoading = true
        guard var components = URLComponents(string: "/mailbox/query_feedback_mails") else { return }
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(currentPage)"),
            URLQueryItem(name: "size", value: "\(pageSize)")
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .get, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: FeedbackMailResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            DispatchQueue.main.async {
                self.isLoading = false
            }
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        for mail in unwrappedData.mails {
                            self.mails.append(FeedbackMailInfo(from: mail))
                        }
                    }
                    if unwrappedData.mails.count < self.pageSize {
                        self.hasMoreMails = false
                    } else {
                        self.hasMoreMails = true
                        self.currentPage += 1
                    }
                }
            default: break
            }
        }
    }
    
    func handleFeedback() {
        guard let mailID = selectedMail?.mailID else { return }
        guard var components = URLComponents(string: "/mailbox/handle_feedback_mail") else { return }
        components.queryItems = [
            URLQueryItem(name: "mail_id", value: mailID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .post, isInternal: true)
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    if let index = self.mails.firstIndex(where: { $0.mailID == mailID }) {
                        self.mails.remove(at: index)
                    }
                default: break
                }
                self.selectedMail = nil
            }
        }
    }
}

struct FeedbackMailInfo: Identifiable, Equatable {
    var id: String { return mailID }
    let mailID: String
    let mailType: FeedbackMailType
    let userContactInfo: String?
    let content: String
    let images: [String]
    let isHandled: Bool
    let createdDate: Date?
    
    init(from mail: FeedbackMailDTO) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        mailID = mail.mail_id
        mailType = mail.mail_type
        userContactInfo = mail.user_contact_info
        content = mail.content
        images = mail.images
        isHandled = mail.is_handled
        createdDate = formatter.date(from: mail.created_at)
    }
    
    static func == (lhs: FeedbackMailInfo, rhs: FeedbackMailInfo) -> Bool {
        return lhs.mailID == rhs.mailID
    }
}

struct FeedbackMailDTO: Codable {
    let mail_id: String
    let mail_type: FeedbackMailType
    let user_contact_info: String?
    let content: String
    let images: [String]
    let is_handled: Bool
    let created_at: String
}

struct FeedbackMailResponse: Codable {
    let mails: [FeedbackMailDTO]
}

class HomepageBackendViewModel: ObservableObject {
    @Published var ads: [AdCardInternalEntry] = []
    
    var hasMoreAds: Bool = true
    var currentPage: Int = 1
    var selectedAdID: String = ""
    var image_url: String = ""
}

struct AdCardInternalEntry: Identifiable, Equatable {
    var id: String {ad_id}
    let ad_id: String
    let image_url: String
    let web_url: String?
    let is_displayed: Bool
    
    init(from ad: AdCardInternalDTO) {
        self.ad_id = ad.ad_id
        self.image_url = ad.image_url
        self.web_url = ad.web_url
        self.is_displayed = ad.is_displayed
    }
    
    static func == (lhs: AdCardInternalEntry, rhs: AdCardInternalEntry) -> Bool {
        return lhs.id == rhs.id
    }
}

struct AdCardInternalDTO: Codable {
    let ad_id: String
    let image_url: String
    let web_url: String?
    let is_displayed: Bool
}

struct AdInfoInternalResponse: Codable {
    let ads: [AdCardInternalDTO]
}

#endif
