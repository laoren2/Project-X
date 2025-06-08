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
    @Published var gender: String = "male"
    @Published var leaderboardEntries: [LeaderboardEntry] = []
    @Published var cityName: String = "未知"
    @Published var cities: [String] = [] // 支持的城市名列表
    @Published var isLoadingMore = false // 排行榜是否处在加载状态
    @Published var selectedEventIndex: Int = 0 // 当前选择的赛事索引
    
    @Published var isTodaySigned: Bool = false
    @Published var signedInDays: [Bool] = Array(repeating: false, count: 7)
    
    // 订阅位置更新及授权
    private var locationCancellable: AnyCancellable?
    private var authorizationCancellable: AnyCancellable?
    
    // 上一次位置更新时记录的位置，用于截流
    private var lastLocation: CLLocation?
    // 上一次位置更新时记录的时间，用于截流
    private var lastLocationUpdateTime: Date?
    
    private var shouldUseAutoLocation = true // 是否使用自动定位
    private var currentPage = 0 // 当前排行榜分页页码
    private var leaderboardFetchCount = 0 // 更新排行榜的引用计数，在频繁更新时显示加载状态
    
    let appState = AppState.shared
    let userManager = UserManager.shared

    var ads: [Ad] = [
        Ad(imageURL: "https://example.com/ad3.jpg"),
        Ad(imageURL: "https://example.com/ad3.jpg"),
        Ad(imageURL: "https://s2.loli.net/2024/12/31/ZqR3uWdXTtUELsB.jpg"),
        Ad(imageURL: "https://s2.loli.net/2024/12/31/ZqR3uWdXTtUELsB.jpg"),
        Ad(imageURL: "https://s2.loli.net/2024/12/31/ZqR3uWdXTtUELsB.jpg")
    ]
    
    var business: [Ad] = [
        Ad(imageURL: "https://example.com/ad3.jpg"),
        Ad(imageURL: "https://example.com/ad3.jpg"),
        Ad(imageURL: "https://s2.loli.net/2024/12/31/ZqR3uWdXTtUELsB.jpg")
    ]

    @Published var events: [Event] = [] // 赛事列表
    @Published var tracks: [Track] = []
    
    // 功能组件数据
    let features = [
        FeatureComponent(iconName: "star.fill", title: "技巧", destination: .skillView),
        FeatureComponent(iconName: "star.fill", title: "活动", destination: .activityView)
        //FeatureComponent(iconName: "star.fill", title: "钱包2", destination: "navigateToWallet"),
        //FeatureComponent(iconName: "star.fill", title: "钱包3", destination: "navigateToWallet")
        //Feature(iconName: "star.fill", title: "功能5", destination: "navigateToWallet")
    ]

    override init() {
        super.init()
        setupLocationSubscription()
        if let location = LocationManager.shared.getLocation() {
            self.fetchCityName(from: location)
        }
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
        DispatchQueue.main.async {
            self.fetchCityName(from: location)
        }
        deleteLocationSubscription()
    }
        
    private func handleAuthorizationStatusChange(_ status: CLAuthorizationStatus) {
        if status != .authorizedAlways && status != .authorizedWhenInUse && shouldUseAutoLocation {
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
    
    func isSignedIn(day: Int) -> Bool {
        return signedInDays[day]
    }
        
    func signInToday() {
        let today = Calendar.current.component(.weekday, from: Date()) - 1
        signedInDays[today] = true
        isTodaySigned = true
    }
    
    func fetchSignInStatus() {
        // todo
        isTodaySigned = isSignedIn(day: Calendar.current.component(.weekday, from: Date()) - 1)
    }
    
    func fetchMeInLeaderboard() -> LeaderboardEntry {
        return LeaderboardEntry(user_id: "", nickname: "", best_time: 00.00, avatarImageURL: NetworkService.baseDomain + "", predictBonus: 0)
    }

    func fetchLeaderboard(for trackIndex: Int, gender: String, reset: Bool = false) {
        // 确保有选中的赛事和赛道
        //print("count+: \(leaderboardFetchCount)")
        guard !events.isEmpty && selectedEventIndex < events.count else {
            print("没有可用的赛事数据")
            // 清空排行榜数据
            if reset {
                leaderboardEntries = []
            }
            return
        }
        
        let event = events[selectedEventIndex]
        guard trackIndex >= 0 && trackIndex < event.tracks.count else {
            print("没有可用的赛道数据或赛道索引无效: \(trackIndex)")
            // 清空排行榜数据
            if reset {
                leaderboardEntries = []
            }
            return
        }
        
        let track = event.tracks[trackIndex]
        
        // 模拟网络请求，这里需要替换成真实的网络请求代码
        if reset {
            currentPage = 0
            leaderboardEntries = []
        }
        
        isLoadingMore = true
        leaderboardFetchCount += 1
        
        print("获取排行榜数据: 赛事[\(event.name)], 赛道[\(track.name)], 性别[\(gender)], 页码[\(currentPage)]")
        
        
        
        // 模拟网络请求
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            // 模拟不同赛事和赛道的排行榜数据
            var newEntries: [LeaderboardEntry] = []
            
            // 根据不同的赛事和赛道生成不同的排行榜数据
            for i in 1...20 {
                let userId = "user\(i + self.currentPage * 20)_\(event.name)_\(track.name)"
                let nickname = "选手\(i + self.currentPage * 20)"
                
                // 根据性别和赛道生成不同的成绩
                let baseTime: Double
                if gender == "male" {
                    baseTime = track.name.contains("全程") ? 9000.0 : (track.name.contains("半程") ? 4500.0 : 1800.0)
                } else {
                    baseTime = track.name.contains("全程") ? 10800.0 : (track.name.contains("半程") ? 5400.0 : 2100.0)
                }
                
                // 添加一些随机性
                let randomFactor = Double(arc4random_uniform(1000)) / 10.0
                let bestTime = baseTime + randomFactor - Double(i) * 30.0 // 排名越高，成绩越好
                
                newEntries.append(LeaderboardEntry(
                    user_id: userId,
                    nickname: nickname,
                    best_time: bestTime,
                    avatarImageURL: "https://example.com/avatar/\(userId).jpg",
                    predictBonus: 0
                ))
            }
            
            DispatchQueue.main.async {
                self.leaderboardFetchCount -= 1
                //print("count-: \(self.leaderboardFetchCount)")
                if self.leaderboardFetchCount == 0 {
                    self.leaderboardEntries.append(contentsOf: newEntries)
                    self.currentPage += 1
                    self.isLoadingMore = false
                    print("fetchLeaderboard success: \(gender),\(self.currentPage)")
                }
            }
        }
    }
    
    func loadMoreEntries() {
        guard !isLoadingMore else { return }
        
        // 确保有选中的赛事和赛道
        guard !events.isEmpty &&
              selectedEventIndex < events.count &&
              selectedTrackIndex >= 0 &&
              selectedTrackIndex < events[selectedEventIndex].tracks.count else {
            print("无法加载更多数据：没有可用的赛事或赛道")
            return
        }
        
        fetchLeaderboard(for: selectedTrackIndex, gender: gender)
    }
    
    func fetchCities() {
        // 模拟网络请求获取城市列表，这里需要替换成真实的网络请求代码
        self.cities = ["北京市", "上海市", "广州市", "深圳市"]
    }

    func fetchCityName(from location: CLLocation, enforce: Bool = false) {
        if !enforce {
            // 位置截流
            if let lastLocation = lastLocation, location.distance(from: lastLocation) < 100 {
                return
            }
            // 时间截流
            if let lastLocationUpdateTime = lastLocationUpdateTime, Date().timeIntervalSince(lastLocationUpdateTime) < 2 {
                return
            }
        }
        lastLocation = location
        lastLocationUpdateTime = Date()
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
            guard let self = self else { return }
            if let placemark = placemarks?.first, let city = placemark.locality, !city.isEmpty, city != self.cityName {
                print("\(city)--\(self.cityName)")
                self.cityName = city
                appState.config.location = city
                // 城市变更后，获取该城市的赛事信息
                self.fetchEventsByCity(city)
            }
        }
    }

    func selectCity(_ city: String) {
        shouldUseAutoLocation = false
        cityName = city
        // 城市变更后，获取该城市的赛事信息
        fetchEventsByCity(city)
    }
    
    func enableAutoLocation() {
        // 启用自动定位
        shouldUseAutoLocation = true
        
        guard let location = LocationManager.shared.getLocation() else {
            cityName = "未知"
            resetEvents()
            print("No location data available.")
            return
        }
        // 强制刷新一次
        fetchCityName(from: location, enforce: true)
    }
    
    func resetEvents() {
        events = []
        tracks = []
        leaderboardEntries = []
        selectedEventIndex = 0
        selectedTrackIndex = 0
    }

    // 根据城市获取赛事信息
    func fetchEventsByCity(_ city: String) {
        // 清空当前赛事和赛道数据
        print("fetchEventsByCity: \(city)")
        events = []
        tracks = []
        leaderboardEntries = [] // 清空排行榜数据
        selectedEventIndex = 0
        selectedTrackIndex = 0
        
        // 显示加载状态
        // 这里可以添加一个加载指示器
        //let isLoading = true
        
        // 模拟网络请求，这里需要替换成真实的网络请求代码
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            // 模拟从服务器获取的数据
            var cityEvents: [Event] = []
            
            // 模拟网络请求可能的错误
            let hasError = false // 设置为true可以模拟请求失败
            let errorMessage = "网络连接失败，请稍后重试"
            
            if hasError {
                // 处理错误情况
                DispatchQueue.main.async {
                    // 这里可以显示错误提示
                    print("获取赛事信息失败: \(errorMessage)")
                    // 隐藏加载指示器
                }
                return
            }
            
            // 正常情况下获取数据
            if city == "北京市" {
                cityEvents = [
                    Event(eventIndex: 0, name: "北京马拉松", city: city, description: "北京国际马拉松赛事", startTime: .now, endTime: .now, tracks: [
                        Track(trackIndex: 0, name: "全程马拉松", eventName: "北京马拉松",
                              from: CLLocationCoordinate2D(latitude: 39.90, longitude: 116.39),
                              to: CLLocationCoordinate2D(latitude: 39.95, longitude: 116.45),
                              elevationDifference: 145,
                              regionName: "天安门-奥林匹克公园",
                              fee: 50,
                              prizePool: 50000,
                              totalParticipants: 5283,
                              currentParticipants: 238),
                        Track(trackIndex: 1, name: "半程马拉松", eventName: "北京马拉松",
                              from: CLLocationCoordinate2D(latitude: 39.92, longitude: 116.40),
                              to: CLLocationCoordinate2D(latitude: 39.97, longitude: 116.43),
                              elevationDifference: 86,
                              regionName: "三里屯-奥林匹克公园",
                              fee: 50,
                              prizePool: 20000,
                              totalParticipants: 8742,
                              currentParticipants: 456)
                    ]),
                    Event(eventIndex: 1, name: "奥林匹克公园跑步赛", city: city, description: "奥林匹克公园跑步挑战赛", startTime: .now, endTime: .now, tracks: [
                        Track(trackIndex: 0, name: "5公里赛道", eventName: "奥林匹克公园跑步赛",
                              from: CLLocationCoordinate2D(latitude: 40.00, longitude: 116.38),
                              to: CLLocationCoordinate2D(latitude: 40.02, longitude: 116.40),
                              elevationDifference: 25,
                              regionName: "奥林匹克公园",
                              fee: 50,
                              prizePool: 5000,
                              totalParticipants: 12453,
                              currentParticipants: 789),
                        Track(trackIndex: 1, name: "10公里赛道", eventName: "奥林匹克公园跑步赛",
                              from: CLLocationCoordinate2D(latitude: 40.00, longitude: 116.38),
                              to: CLLocationCoordinate2D(latitude: 40.04, longitude: 116.42),
                              elevationDifference: 45,
                              regionName: "奥林匹克公园-森林公园",
                              fee: 50,
                              prizePool: 8000,
                              totalParticipants: 7652,
                              currentParticipants: 321)
                    ])
                ]
            } else if city == "上海市" {
                cityEvents = [
                    Event(eventIndex: 0, name: "上海马拉松", city: city, description: "上海国际马拉松赛事", startTime: .now, endTime: .now, tracks: [
                        Track(trackIndex: 0, name: "全程马拉松", eventName: "上海马拉松",
                              from: CLLocationCoordinate2D(latitude: 31.23, longitude: 121.47),
                              to: CLLocationCoordinate2D(latitude: 31.28, longitude: 121.52),
                              elevationDifference: 112,
                              regionName: "外滩-浦东新区",
                              fee: 60,
                              prizePool: 60000,
                              totalParticipants: 6789,
                              currentParticipants: 345),
                        Track(trackIndex: 1, name: "半程马拉松", eventName: "上海马拉松",
                              from: CLLocationCoordinate2D(latitude: 31.24, longitude: 121.48),
                              to: CLLocationCoordinate2D(latitude: 31.26, longitude: 121.50),
                              elevationDifference: 65,
                              regionName: "人民广场-世纪公园",
                              fee: 60,
                              prizePool: 25000,
                              totalParticipants: 9876,
                              currentParticipants: 567)
                    ]),
                    Event(eventIndex: 1, name: "上海城市定向赛", city: city, description: "上海城市定向挑战赛", startTime: .now, endTime: .now, tracks: [
                        Track(trackIndex: 0, name: "初级赛道", eventName: "上海城市定向赛",
                              from: CLLocationCoordinate2D(latitude: 31.0051, longitude: 121.4098),
                              to: CLLocationCoordinate2D(latitude: 31.24, longitude: 121.48),
                              elevationDifference: 35,
                              regionName: "徐家汇",
                              fee: 60,
                              prizePool: 300,
                              totalParticipants: 532,
                              currentParticipants: 34),
                        Track(trackIndex: 1, name: "中级赛道", eventName: "上海城市定向赛",
                              from: CLLocationCoordinate2D(latitude: 31.22, longitude: 121.46),
                              to: CLLocationCoordinate2D(latitude: 31.25, longitude: 121.49),
                              elevationDifference: 48,
                              regionName: "南京路-淮海路",
                              fee: 60,
                              prizePool: 5000,
                              totalParticipants: 3421,
                              currentParticipants: 189),
                        Track(trackIndex: 2, name: "高级赛道", eventName: "上海城市定向赛",
                              from: CLLocationCoordinate2D(latitude: 31.22, longitude: 121.46),
                              to: CLLocationCoordinate2D(latitude: 31.26, longitude: 121.50),
                              elevationDifference: 82,
                              regionName: "上海全市范围",
                              fee: 60,
                              prizePool: 8000,
                              totalParticipants: 2156,
                              currentParticipants: 105)
                    ])
                ]
            } else if city == "广州市" {
                cityEvents = [
                    Event(eventIndex: 0, name: "广州马拉松", city: city, description: "广州国际马拉松赛事", startTime: .now, endTime: .now, tracks: [
                        Track(trackIndex: 0, name: "全程马拉松", eventName: "广州马拉松",
                              from: CLLocationCoordinate2D(latitude: 23.12, longitude: 113.25),
                              to: CLLocationCoordinate2D(latitude: 23.17, longitude: 113.30),
                              elevationDifference: 128,
                              regionName: "天河体育中心-白云山",
                              fee: 30,
                              prizePool: 45000,
                              totalParticipants: 7123,
                              currentParticipants: 412),
                        Track(trackIndex: 1, name: "半程马拉松", eventName: "广州马拉松",
                              from: CLLocationCoordinate2D(latitude: 23.13, longitude: 113.26),
                              to: CLLocationCoordinate2D(latitude: 23.15, longitude: 113.28),
                              elevationDifference: 76,
                              regionName: "珠江新城-白云区",
                              fee: 30,
                              prizePool: 18000,
                              totalParticipants: 9245,
                              currentParticipants: 532)
                    ])
                ]
            } else if city == "深圳市" {
                cityEvents = [
                    Event(eventIndex: 0, name: "深圳马拉松", city: city, description: "深圳国际马拉松赛事", startTime: .now, endTime: .now, tracks: [
                        Track(trackIndex: 0, name: "全程马拉松", eventName: "深圳马拉松",
                              from: CLLocationCoordinate2D(latitude: 22.53, longitude: 114.05),
                              to: CLLocationCoordinate2D(latitude: 22.58, longitude: 114.10),
                              elevationDifference: 135,
                              regionName: "福田中心区-南山区",
                              fee: 30,
                              prizePool: 55000,
                              totalParticipants: 6543,
                              currentParticipants: 378),
                        Track(trackIndex: 1, name: "半程马拉松", eventName: "深圳马拉松",
                              from: CLLocationCoordinate2D(latitude: 22.54, longitude: 114.06),
                              to: CLLocationCoordinate2D(latitude: 22.56, longitude: 114.08),
                              elevationDifference: 68,
                              regionName: "福田CBD-深圳湾",
                              fee: 30,
                              prizePool: 22000,
                              totalParticipants: 8765,
                              currentParticipants: 489)
                    ]),
                    Event(eventIndex: 1, name: "深圳湾跑步赛", city: city, description: "深圳湾公园跑步挑战赛", startTime: .now, endTime: .now, tracks: [
                        Track(trackIndex: 0, name: "5公里赛道", eventName: "深圳湾跑步赛",
                              from: CLLocationCoordinate2D(latitude: 22.50, longitude: 113.95),
                              to: CLLocationCoordinate2D(latitude: 22.52, longitude: 113.97),
                              elevationDifference: 15,
                              regionName: "深圳湾公园",
                              fee: 30,
                              prizePool: 4000,
                              totalParticipants: 10876,
                              currentParticipants: 745),
                        Track(trackIndex: 1, name: "10公里赛道", eventName: "深圳湾跑步赛",
                              from: CLLocationCoordinate2D(latitude: 22.50, longitude: 113.95),
                              to: CLLocationCoordinate2D(latitude: 22.54, longitude: 113.99),
                              elevationDifference: 42,
                              regionName: "深圳湾-红树林",
                              fee: 30,
                              prizePool: 7500,
                              totalParticipants: 6543,
                              currentParticipants: 398)
                    ])
                ]
            } else {
                // 默认赛事数据，当城市不在支持列表中时使用
                cityEvents = [
                    Event(eventIndex: 0, name: "未知马拉松", city: city, description: "未知马拉松赛事", startTime: .now, endTime: .now, tracks: [
                        Track(trackIndex: 0, name: "5公里赛道", eventName: "未知马拉松",
                              from: CLLocationCoordinate2D(latitude: 31.00, longitude: 121.40),
                              to: CLLocationCoordinate2D(latitude: 31.02, longitude: 121.42),
                              elevationDifference: 20,
                              regionName: "未知区域",
                              fee: 10,
                              prizePool: 2000,
                              totalParticipants: 1000,
                              currentParticipants: 100),
                        Track(trackIndex: 1, name: "10公里赛道", eventName: "未知马拉松",
                              from: CLLocationCoordinate2D(latitude: 31.00, longitude: 121.40),
                              to: CLLocationCoordinate2D(latitude: 31.04, longitude: 121.44),
                              elevationDifference: 30,
                              regionName: "未知区域",
                              fee: 10,
                              prizePool: 3000,
                              totalParticipants: 1500,
                              currentParticipants: 150)
                    ])
                ]
            }
            
            // 在主线程更新UI
            DispatchQueue.main.async {
                self.events = cityEvents
                
                // 初始化默认选中的赛事和赛道
                if !self.events.isEmpty {
                    // 确保选中的赛事有赛道
                    if !self.events[self.selectedEventIndex].tracks.isEmpty {
                        self.tracks = self.events[self.selectedEventIndex].tracks
                        // 获取排行榜数据
                        self.fetchLeaderboard(for: self.selectedTrackIndex, gender: self.gender, reset: true)
                    } else {
                        print("选中的赛事没有可用的赛道")
                        self.tracks = []
                    }
                } else {
                    print("没有找到该城市的赛事信息")
                }
                // 隐藏加载指示器
            }
        }
    }
    
    // 切换赛事
    func switchEvent(to eventIndex: Int) {
        guard eventIndex >= 0 && eventIndex < events.count else {
            print("无效的赛事索引: \(eventIndex)")
            return
        }
        
        selectedEventIndex = eventIndex
        
        // 确保赛事有赛道
        if events[eventIndex].tracks.isEmpty {
            print("该赛事没有可用的赛道")
            tracks = []
            selectedTrackIndex = 0
            leaderboardEntries = [] // 清空排行榜数据
            return
        }
        
        tracks = events[eventIndex].tracks
        selectedTrackIndex = 0 // 重置为第一个赛道
        
        // 重新获取排行榜数据
        fetchLeaderboard(for: selectedTrackIndex, gender: gender, reset: true)
    }
}

struct LeaderboardEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let user_id: String
    let nickname: String
    let best_time: TimeInterval
    let avatarImageURL: String
    let predictBonus: Int
    
    init(id: UUID = UUID(), user_id: String = "null", nickname: String = "null", best_time: TimeInterval = 0.0, avatarImageURL: String, predictBonus: Int = 0) {
        self.id = id
        self.user_id = user_id
        self.nickname = nickname
        self.best_time = best_time
        self.avatarImageURL = avatarImageURL
        self.predictBonus = predictBonus
    }
    
    static func == (lhs: LeaderboardEntry, rhs: LeaderboardEntry) -> Bool {
        return lhs.user_id == rhs.user_id
    }
}

struct Ad: Identifiable {
    let id = UUID()
    let imageURL: String
}

struct FeatureComponent: Identifiable {
    let id = UUID()
    let iconName: String
    let title: String
    let destination: AppRoute
}




