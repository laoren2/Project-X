//
//  SportCenterViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2024/12/28.
//

import Foundation
import CoreLocation
import Combine
import MapKit


enum RoutePoint {
    case checkpoint(Checkpoint)
    case segment(Segment)

    func toRealtimePoint() -> RoutePointRealtime {
        switch self {
        case .checkpoint(let checkpoint):
            let point = CheckpointRealtime(lat: checkpoint.lat, lng: checkpoint.lng, radius: checkpoint.radius, isCheck: false, isMiss: false, penalty: checkpoint.penalty)
            return .checkpoint(point)
        case .segment(let segment):
            let curve = SegmentRealtime(points: segment.points, width: segment.width, checkProgress: 0)
            return .segment(curve)
        }
    }
}

struct Checkpoint {
    let lat: Double
    let lng: Double
    let radius: Double
    let penalty: Int?
}

struct Segment {
    let points: [CLLocationCoordinate2D]
    let width: Double
}

enum RoutePointRealtime {
    case checkpoint(CheckpointRealtime)
    case segment(SegmentRealtime)
}

struct CheckpointRealtime {
    let lat: Double
    let lng: Double
    let radius: Double
    var isCheck: Bool
    var isMiss: Bool
    var penalty: Int?
}

struct SegmentRealtime {
    let points: [CLLocationCoordinate2D]
    let width: Double
    var checkProgress: Double
}


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

final class MapCameraState: ObservableObject {
    weak var mapView: MKMapView?
    // 发布给 SwiftUI
    @Published var metersPerPoint: Double = 1.0

    func update(from mapView: MKMapView) {
        self.mapView = mapView
        
        let p1 = CGPoint(x: mapView.bounds.midX, y: mapView.bounds.midY)
        let p2 = CGPoint(x: mapView.bounds.midX + 1, y: mapView.bounds.midY)
        
        let c1 = mapView.convert(p1, toCoordinateFrom: mapView)
        let c2 = mapView.convert(p2, toCoordinateFrom: mapView)
        
        let l1 = CLLocation(latitude: c1.latitude, longitude: c1.longitude)
        let l2 = CLLocation(latitude: c2.latitude, longitude: c2.longitude)
        
        metersPerPoint = l1.distance(from: l2)
    }

    func project(_ coordinate: CLLocationCoordinate2D) -> CGPoint {
        guard let mapView else { return .zero }
        return mapView.convert(coordinate, toPointTo: mapView)
    }

    func coordinate(from point: CGPoint) -> CLLocationCoordinate2D {
        guard let mapView else { return CLLocationCoordinate2D() }
        return mapView.convert(point, toCoordinateFrom: mapView)
    }
}

final class RouteEditorStore: ObservableObject, NavigationStore {
    @Published var routePoints: [EditableRoutePoint] = []
    @Published var tempRoutePoints: [EditableRoutePoint] = []
    @Published var selectedType: RouteType = .pointToPoint
    @Published var tempSelectedType: RouteType = .pointToPoint
    
    @Published var routeElevationDiff: Int? = nil       // 海拔差/m
    @Published var isLoadingElevation = false
    
    lazy var id: UUID = {
        NavigationStoreManager.shared.register(self)
    }()
    
    enum RouteValidationError {
        case notEnoughPoints
        case invalidStructure
        case radiusOverlap
        case outOfBounds
    }
    
    func saveValidPath() -> RouteValidationError? {
        // 基础数量校验
        guard tempRoutePoints.count >= 2 else { return .notEnoughPoints }
        
        // 统计类型
        let starts = tempRoutePoints.filter {
            if case .start = $0.type { return true }
            return false
        }
        let ends = tempRoutePoints.filter {
            if case .end = $0.type { return true }
            return false
        }
        
        // 起点终点必须唯一
        guard starts.count == 1, ends.count == 1 else { return .invalidStructure }
        
        // 顺序校验
        guard case .start = tempRoutePoints.first?.type,
              case .end = tempRoutePoints.last?.type else {
            return .invalidStructure
        }
        
        switch tempSelectedType {
        case .pointToPoint:
            // 必须只有两个点：start -> end
            guard tempRoutePoints.count == 2 else { return .invalidStructure }
            
        case .multiPoints:
            // 至少三个点（start + checkPoint(s) + end）
            guard tempRoutePoints.count >= 3 else { return .invalidStructure }
            
            // 中间点必须都是 checkPoint
            let middlePoints = tempRoutePoints.dropFirst().dropLast()
            let allCheckPoint = middlePoints.allSatisfy {
                if case .checkPoint = $0.type { return true }
                return false
            }
            guard allCheckPoint else { return .invalidStructure }
        }

        // 半径校验：任意两个点的距离必须大于半径之和
        for i in 0..<tempRoutePoints.count {
            for j in (i + 1)..<tempRoutePoints.count {
                let p1 = tempRoutePoints[i]
                let p2 = tempRoutePoints[j]
                
                let loc1 = CLLocation(latitude: p1.coordinate.latitude, longitude: p1.coordinate.longitude)
                let loc2 = CLLocation(latitude: p2.coordinate.latitude, longitude: p2.coordinate.longitude)
                
                let distance = loc1.distance(from: loc2)
                let minAllowed = p1.radius + p2.radius + 10
                
                if distance <= minAllowed {
                    return .radiusOverlap
                }
            }
        }
        
        // 边界校验
        let polygons = LocationManager.shared.regionBoundary
        for point in tempRoutePoints {
            if !isCoordinate(point.coordinate, inside: polygons) {
                return .outOfBounds
            }
        }
        
        // 校验通过，提交
        routePoints = tempRoutePoints
        selectedType = tempSelectedType
        return nil
    }
    
    func fetchElevation() {
        guard tempRoutePoints.count >= 2 else { return }
        
        guard let lat1 = tempRoutePoints.first?.coordinate.latitude,
              let lng1 = tempRoutePoints.first?.coordinate.longitude,
              let lat2 = tempRoutePoints.last?.coordinate.latitude,
              let lng2 = tempRoutePoints.last?.coordinate.longitude else { return }
        
        guard var components = URLComponents(string: "/common/elevation_diff") else { return }
        components.queryItems = [
            URLQueryItem(name: "lat1", value: "\(lat1)"),
            URLQueryItem(name: "lng1", value: "\(lng1)"),
            URLQueryItem(name: "lat2", value: "\(lat2)"),
            URLQueryItem(name: "lng2", value: "\(lng2)")
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .get)
        DispatchQueue.main.async {
            self.isLoadingElevation  = true
        }
        NetworkService.sendRequest(with: request, decodingType: Int?.self) { result in
            DispatchQueue.main.async {
                self.isLoadingElevation = false
                switch result {
                case .success(let data):
                    if let unwrappedData = data {
                        self.routeElevationDiff = unwrappedData
                    }
                default: break
                }
            }
        }
    }
    
    func isPointOverlapping(id: UUID) -> Bool {
        guard let p1 = tempRoutePoints.first(where: { $0.id == id }) else {
            return false
        }

        for p2 in tempRoutePoints where p2.id != id {
            let loc1 = CLLocation(latitude: p1.coordinate.latitude, longitude: p1.coordinate.longitude)
            let loc2 = CLLocation(latitude: p2.coordinate.latitude, longitude: p2.coordinate.longitude)

            let distance = loc1.distance(from: loc2)
            let minAllowed = p1.radius + p2.radius + 10

            if distance <= minAllowed {
                return true
            }
        }
        return false
    }
    
    func isCoordinate(_ coord: CLLocationCoordinate2D, inside polygons: [MKPolygon]) -> Bool {
        let point = MKMapPoint(coord)
        for polygon in polygons {
            var isInside = false
            let points = polygon.points()
            let count = polygon.pointCount
            
            var j = count - 1
            for i in 0..<count {
                let pi = points[i]
                let pj = points[j]
                
                let intersect = ((pi.y > point.y) != (pj.y > point.y)) &&
                (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y + 0.0000001) + pi.x)
                
                if intersect {
                    isInside.toggle()
                }
                j = i
            }
            if isInside { return true }
        }
        return false
    }
}

struct EditableRoutePoint: Identifiable {
    let id = UUID()
    var coordinate: CLLocationCoordinate2D
    var radius: Double = 20
    var penalty: Int? = nil
    var type: EditableCheckPointType
    //var isOverlapping: Bool = false
    var isOutOfBounds: Bool = false
    
    func toRoutePoint() -> RoutePoint {
        .checkpoint(
            Checkpoint(
                lat: coordinate.latitude,
                lng: coordinate.longitude,
                radius: radius,
                penalty: penalty
            )
        )
    }
}

extension Array where Element == EditableRoutePoint {
    func toRoutePoints() -> [RoutePoint] {
        map { $0.toRoutePoint() }
    }
}

extension Array where Element == RoutePoint {
    func toRealtimePoints() -> [RoutePointRealtime] {
        map { $0.toRealtimePoint() }
    }

    // 将已存储的路线点（checkpoint，坐标为 wgs84）还原为可编辑点
    // 坐标需转换回展示坐标系（gcj02），并按顺序重建 start/checkPoint/end 类型
    func toEditablePoints() -> [EditableRoutePoint] {
        let checkpoints: [Checkpoint] = compactMap {
            if case .checkpoint(let cp) = $0 { return cp }
            return nil
        }
        var result: [EditableRoutePoint] = []
        for (index, cp) in checkpoints.enumerated() {
            let displayCoord = CoordinateConverter.parseCoordinate(
                coordinate: CLLocationCoordinate2D(latitude: cp.lat, longitude: cp.lng)
            )
            let type: EditableCheckPointType
            if index == 0 {
                type = .start
            } else if index == checkpoints.count - 1 {
                type = .end
            } else {
                type = .checkPoint(index)
            }
            result.append(EditableRoutePoint(
                coordinate: displayCoord,
                radius: cp.radius,
                penalty: cp.penalty,
                type: type
            ))
        }
        return result
    }
}

enum EditableCheckPointType: Equatable {
    case start
    case end
    case checkPoint(Int)
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
    let region_id: String
    let tiles: [TileKey]
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

enum GridEffectType: String, Codable {
    case buff = "buff"
    case debuff = "debuff"
}


enum RouteSortType: String, CaseIterable {
    case distance = "distance"
    case participation = "participation"
    
    var displayName: String {
        switch self {
        case .distance: return "competition.realtime.distance"
        case .participation: return "common.popularity"
        }
    }
}

enum RouteType: String, CaseIterable, Codable {
    case pointToPoint = "pointToPoint"
    case multiPoints = "multiPoints"
    //case curve = "curve"
    //case mixed = "mixed"
    
    var displayName: String {
        switch self {
        case .pointToPoint: return "training.route.mode.direct"
        case .multiPoints: return "training.route.mode.multi-points"
        }
    }
    
    var icon: String {
        switch self {
        case .pointToPoint: return "route_p2p"
        case .multiPoints: return "route_multipoints"
        }
    }
}

