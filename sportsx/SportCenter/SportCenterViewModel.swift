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
    
    @Published var seasonName: String = ""
    
    // 订阅位置更新及授权
    private var locationCancellable: AnyCancellable?
    private var authorizationCancellable: AnyCancellable?
    
    
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
    
    func deleteLocationSubscription() {
        locationCancellable?.cancel()
        authorizationCancellable?.cancel()
    }
    
    private func handleLocationUpdate(_ location: CLLocation) {
        // 更新UI转到主线程上
        DispatchQueue.main.async {
            self.updateCity(from: location)
        }
        deleteLocationSubscription()
    }
    
    private func handleAuthorizationStatusChange(_ status: CLAuthorizationStatus) {
        if status != .authorizedAlways && status != .authorizedWhenInUse {
            locationManager.region = "未知"
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
    }
    
    func fetchCurrentSeason() {
        let urlPath = "/competition/\(AppState.shared.sport.rawValue)/query_season"
            
        let request = APIRequest(path: urlPath, method: .get)
        NetworkService.sendRequest(with: request, decodingType: SeasonResponse.self) { result in
            switch result {
            case .success(let data):
                if let unwrappedDta = data {
                    DispatchQueue.main.async {
                        self.seasonName = unwrappedDta.name
                    }
                }
            default: break
            }
        }
    }
    
    func updateCity(from location: CLLocation, enforce: Bool = false) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
            guard let self = self else { return }
            if let placemark = placemarks?.first {
                if let city = placemark.locality, !city.isEmpty {
                    locationManager.region = city
                    GlobalConfig.shared.location = city
                }
                if let country = placemark.isoCountryCode {
                    locationManager.countryCode = country
                }
            }
        }
    }
}

struct SeasonResponse: Codable {
    let season_id: String
    let name: String
    let start_date: String
    let end_date: String
    let image_url: String
}

struct RegionResponse: Codable {
    let regions_with_events: [String]
}
