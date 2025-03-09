//
//  HomeViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2024/7/20.
//

import Foundation
import Combine
import CoreLocation
import MapKit
import SwiftUI


class HomeViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var selectedTrackIndex: Int = 0
    @Published var leaderboardEntries: [LeaderboardEntry] = []
    @Published var cityName: String = "未知"
    @Published var cities: [String] = [] // 支持的城市名列表
    @Published var isLoadingMore = false // 排行榜是否加载更多
    // 订阅位置更新及授权
    private var locationCancellable: AnyCancellable?
    private var authorizationCancellable: AnyCancellable?
    
    private var shouldUseAutoLocation = true // 是否使用自动定位
    private var currentPage = 0 // 当前排行榜分页页码

    var ads: [Ad] = [
        Ad(imageURL: "https://example.com/ad3.jpg"),
        Ad(imageURL: "https://example.com/ad3.jpg"),
        Ad(imageURL: "https://s2.loli.net/2024/12/31/ZqR3uWdXTtUELsB.jpg"),
        Ad(imageURL: "https://s2.loli.net/2024/12/31/ZqR3uWdXTtUELsB.jpg"),
        Ad(imageURL: "https://s2.loli.net/2024/12/31/ZqR3uWdXTtUELsB.jpg")
    ]

    @Published var tracks: [Track] = [
        Track(trackIndex: 0, name: "赛道 1"),
        Track(trackIndex: 1, name: "赛道 2"),
        Track(trackIndex: 2, name: "赛道 3"),
        Track(trackIndex: 3, name: "赛道 4"),
        Track(trackIndex: 4, name: "赛道 5")
    ]

    override init() {
        super.init()
        //setupLocationSubscription()
        fetchLeaderboard(for: selectedTrackIndex, reset: true)
        fetchCities()
    }
    
    deinit {
        //deleteLocationSubscription()
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
    
    func deleteLocationSubscription() {
        locationCancellable?.cancel()
        authorizationCancellable?.cancel()
    }
    
    private func handleLocationUpdate(_ location: CLLocation) {
        // 更新UI转到主线程上
        // 比赛开始后位置更新频率变高，停止位置更新回调
        if !CompetitionManagerData.shared.isRecording && shouldUseAutoLocation {
            DispatchQueue.main.async {
                self.fetchCityName(from: location)
                //self.updateTracks()
            }
        }
    }
        
    private func handleAuthorizationStatusChange(_ status: CLAuthorizationStatus) {
        if status != .authorizedAlways && status != .authorizedWhenInUse {
            cityName = "未知"
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

    func fetchLeaderboard(for trackIndex: Int, reset: Bool = false) {
        
        // 模拟网络请求，这里需要替换成真实的网络请求代码
        if reset {
            currentPage = 0
            leaderboardEntries = []
        }
        isLoadingMore = true
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            let newEntries = (1...100).map { i in
                LeaderboardEntry(user_id: "user\(i + self.currentPage * 100)", nickname: "User \(i + self.currentPage * 100)", best_time: Double(arc4random_uniform(500) + 100), avatarImageURL: "https://example.com/avatar/user\(i + self.currentPage * 100).jpg")
            }
            DispatchQueue.main.async {
                self.leaderboardEntries.append(contentsOf: newEntries)
                self.isLoadingMore = false
                self.currentPage += 1
            }
        }
        print("rjtest_fetchLeaderboard")
    }
    
    func loadMoreEntries() {
        print("rjtest_loadMoreEntries")
        guard !isLoadingMore else { return }
        fetchLeaderboard(for: selectedTrackIndex)
    }
    
    func fetchCities() {
        // 模拟网络请求获取城市列表，这里需要替换成真实的网络请求代码
        self.cities = ["北京市", "上海市", "广州市", "深圳市"]
    }

    private func fetchCityName(from location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
            guard let self = self else { return }
            if let placemark = placemarks?.first, let city = placemark.locality, !city.isEmpty {
                self.cityName = city
                self.updateTracks()
            }
        }
    }

    func selectCity(_ city: String) {
        shouldUseAutoLocation = false
        cityName = city
        updateTracks()
    }
    
    func enableAutoLocation() {
        // 启用自动定位
        shouldUseAutoLocation = true
        // 强制刷新一次
        guard let location = LocationManager.shared.getLocation() else {
            print("No location data available.")
            return
        }
        fetchCityName(from: location)
    }
    
    func updateTracks() {
        // 向服务器请求并更新track[]
        if tracks[0].city == cityName {return}
        
        for i in tracks.indices {
            tracks[i].city = cityName
            if cityName == "北京市" {
                tracks[i].from = CLLocationCoordinate2D(latitude: 39.9 + Double(i)/10, longitude: 116.5 + Double(i)/10)
                tracks[i].to = CLLocationCoordinate2D(latitude: 40 + Double(i)/10, longitude: 116.2 + Double(i)/10)
            } else if cityName == "上海市" {
                tracks[i].from = CLLocationCoordinate2D(latitude: 45, longitude: 78)
                tracks[i].to = CLLocationCoordinate2D(latitude: 46, longitude: 79)
            } else {
                tracks[i].from = CLLocationCoordinate2D(latitude: 31.007, longitude: 121.405)
                tracks[i].to = CLLocationCoordinate2D(latitude: 31.009, longitude: 121.399)
            }
        }
        print(tracks[0].city)
    }
    
}

struct LeaderboardEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let user_id: String
    let nickname: String
    let best_time: TimeInterval
    let avatarImageURL: String?
    
    init(id: UUID = UUID(), user_id: String = "null", nickname: String = "null", best_time: TimeInterval = 0.0, avatarImageURL: String = "null") {
        self.id = id
        self.user_id = user_id
        self.nickname = nickname
        self.best_time = best_time
        self.avatarImageURL = avatarImageURL
    }
    
    static func == (lhs: LeaderboardEntry, rhs: LeaderboardEntry) -> Bool {
        return lhs.user_id == rhs.user_id
    }
}

struct Ad: Identifiable {
    let id = UUID()
    let imageURL: String
}

struct Track: Identifiable {
    let id = UUID()
    let trackIndex: Int
    let name: String
    var city: String = "未知"
    var from: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    var to: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 1, longitude: 1)
}


