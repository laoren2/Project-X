//
//  SportCenterViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2024/12/28.
//

import Foundation
import CoreLocation
import Combine

class CompetitionCenterViewModel: ObservableObject {
    let locationManager = LocationManager.shared
    
    @Published var seasonInfo: SeasonInfo?
    
    // 订阅位置更新及授权
    private var locationCancellable: AnyCancellable?
    private var authorizationCancellable: AnyCancellable?
    
    init() {
        setupLocationSubscription()
    }
    
    func setupLocationSubscription() {
        // 订阅位置更新
        locationCancellable = LocationManager.shared.locationPublisher()
            .subscribe(on: DispatchQueue.global(qos: .background)) // 后台处理数据发送
            .receive(on: DispatchQueue.global(qos: .background)) // 后台处理数据计算
            .sink { location in
                self.handleLocationUpdate(location)
            }
        // 订阅授权状态变化
        authorizationCancellable = LocationManager.shared.authorizationPublisher()
            .receive(on: DispatchQueue.main)
            .sink { status in
                self.handleAuthorizationStatusChange(status)
            }
    }
    
    private func handleLocationUpdate(_ location: CLLocation) {
        updateCity(from: location)
        locationCancellable?.cancel()
    }
    
    private func handleAuthorizationStatusChange(_ status: CLAuthorizationStatus) {
        if status != .authorizedAlways && status != .authorizedWhenInUse {
            locationManager.regionID = nil
        }
        switch status {
        case .authorizedAlways:
            print("Always权限已获取，可在后台持续获取位置。")
        case .authorizedWhenInUse:
            print("When In Use权限获取，前台可获取位置。")
        case .denied:
            print("定位权限被拒绝，可能需要提示用户前往设置。")
        case .restricted:
            print("定位受限。")
        case .notDetermined:
            print("尚未决定权限，可能需再次请求。")
        @unknown default:
            print("未知的授权状态。")
        }
        authorizationCancellable?.cancel()
    }
    
    func fetchCurrentSeason() {
        let urlPath = "/competition/\(AppState.shared.sport.rawValue)/query_season"
            
        let request = APIRequest(path: urlPath, method: .get)
        NetworkService.sendRequest(with: request, decodingType: SeasonResponse.self) { result in
            switch result {
            case .success(let data):
                if let unwrappedDta = data {
                    DispatchQueue.main.async {
                        self.seasonInfo = SeasonInfo(
                            name: unwrappedDta.name,
                            startDate: ISO8601DateFormatter().date(from: unwrappedDta.start_date),
                            endDate: ISO8601DateFormatter().date(from: unwrappedDta.end_date))
                    }
                }
            case .failure:
                DispatchQueue.main.async {
                    self.seasonInfo = nil
                }
            }
        }
    }
    
    func updateCity(from location: CLLocation) {
        // 兜底 + 快速显示上一次地区信息
        DispatchQueue.main.async {
            self.locationManager.regionID = GlobalConfig.shared.locationID
        }
        
        fetchRegionID(location: location)
        
        /*let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let placemark = placemarks?.first {
                    if let country = placemark.isoCountryCode {
                        self.locationManager.countryCode = country
                    }
                }
            }
        }*/
    }
    
    func fetchRegionID(location: CLLocation) {
        guard var components = URLComponents(string: "/competition/query_region_id") else { return }
        components.queryItems = [
            URLQueryItem(name: "lat", value: "\(location.coordinate.latitude)"),
            URLQueryItem(name: "lon", value: "\(location.coordinate.longitude)")
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .get)
        
        NetworkService.sendRequest(with: request, decodingType: RegionResponse.self, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.locationManager.regionID = unwrappedData.region_id
                        GlobalConfig.shared.locationID = unwrappedData.region_id
                        if let code = unwrappedData.country_code {
                            self.locationManager.country = Country(rawValue: code)
                        } else {
                            self.locationManager.country = nil
                        }
                        if let regionID = unwrappedData.region_id, let _ = unwrappedData.country_code {
                            let userManager = UserManager.shared
                            if userManager.isLoggedIn && userManager.user.enableAutoLocation && userManager.user.location != regionID {
                                userManager.updateUserLocation(regionID: regionID)
                            }
                            UserDefaults.standard.set(regionID, forKey: "global.regionID")
                        }
                    }
                }
            default: break
            }
        }
    }
}

struct SeasonInfo {
    let name: String
    let startDate: Date?
    let endDate: Date?
}

struct SeasonResponse: Codable {
    let season_id: String
    let name: String
    let start_date: String
    let end_date: String
    let image_url: String
}

struct RegionIDResponse: Codable {
    let regions_with_events: [String]
}

struct RegionResponse: Codable {
    let region_id: String?
    let country_code: String?
}

struct TrainingGridTileRequest: Codable {
    let tiles: [TileKey]
}

struct TrainingGridTile: Codable {
    let key: TileKey
    let cells: [GridCell]
}

struct TrainingGridTileResponse: Codable {
    let tiles: [TrainingGridTile]
}

struct GridBboxConfig: Codable, Equatable, Hashable {
    let originLat: Double
    let originLng: Double
    let endLat: Double
    let endLng: Double
}

struct GridCell: Codable {
    let grid_x: Int
    let grid_y: Int
    let count: Int
}

struct TileKey: Hashable, Codable {
    let level: Int
    let x: Int
    let y: Int
}

struct RegionExploreResponse: Codable {
    let explored_grids: Int
    let total_grids: Int
    let boundary: JSONValue
}

struct GridSelection: Identifiable {
    let id = UUID()
    let gridX: Int
    let gridY: Int
    let level: Int
}

struct GridFamiliarityMeInfo: Codable {
    let count: Int
    let rank: Int
}

struct GridFamiliarityRankResponse: Codable {
    let data: [GridFamiliarityRankDTO]
}

struct GridFamiliarityRankDTO: Codable {
    let user: PersonInfoDTO
    let count: Int
    let rank: Int
}

struct GridFamiliarityRankInfo: Identifiable {
    var id: String { userID }
    let userID: String
    let avatarUrl: String
    let nickName: String
    let count: Int
    let rank: Int
    
    init(from dto: GridFamiliarityRankDTO) {
        self.userID = dto.user.user_id
        self.avatarUrl = dto.user.avatar_image_url
        self.nickName = dto.user.nickname
        self.count = dto.count
        self.rank = dto.rank
    }
}
