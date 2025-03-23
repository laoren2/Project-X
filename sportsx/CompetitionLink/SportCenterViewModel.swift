//
//  SportCenterViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2024/12/28.
//

import Foundation
import CoreLocation
import Combine

class SportCenterViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var cityName: String = "未知"
    @Published var selectedSport: SportName = .Bike // 默认运动
    // 订阅位置更新
    private var locationCancellable: AnyCancellable?
    let competitionManager = CompetitionManager.shared
    
    @Published var selectedTrackIndex: Int = 0
    @Published var selectedEventIndex: Int = 0 // 当前选择的赛事索引
    @Published var events: [Event] = [] // 赛事列表
    @Published var tracks: [Track] = [] // 赛道列表
    
    
    func setupLocationSubscription() {
        // 订阅位置更新
        locationCancellable = LocationManager.shared.locationPublisher()
            .subscribe(on: DispatchQueue.global(qos: .background)) // 后台处理数据发送
            .receive(on: DispatchQueue.global(qos: .background)) // 后台处理数据计算
            .sink { location in
                self.handleLocationUpdate(location)
            }
    }
    
    func deleteLocationSubscription() {
        locationCancellable?.cancel()
    }
    
    private func handleLocationUpdate(_ location: CLLocation) {
        // 更新UI转到主线程上
        // 比赛开始后位置更新频率变高，停止位置更新回调
        if !competitionManager.isRecording {
            DispatchQueue.main.async {
                self.fetchCityName(from: location)
                print("centerView fetchCityName")
            }
        }
    }
    
    func fetchCityName(from location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
            guard let self = self else { return }
            if let placemark = placemarks?.first, let city = placemark.locality, !city.isEmpty, city != self.cityName {
                print("\(city)--\(self.cityName)")
                self.cityName = city
                // 城市变更后，获取该城市的赛事信息
                self.fetchEventsByCity(city)
            }
        }
    }
    
    // 根据城市获取赛事信息
    func fetchEventsByCity(_ city: String) {
        // 清空当前赛事和赛道数据
        print("centerView fetchEventsByCity: \(city)")
        events = []
        tracks = []
        selectedEventIndex = 0
        selectedTrackIndex = 0
        
        // 显示加载状态
        // 这里可以添加一个加载指示器
        let isLoading = true
        
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
                    Event(eventIndex: 0, name: "北京马拉松", city: city, description: "北京国际马拉松赛事", tracks: [
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
                    Event(eventIndex: 1, name: "奥林匹克公园跑步赛", city: city, description: "奥林匹克公园跑步挑战赛", tracks: [
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
                    Event(eventIndex: 0, name: "上海马拉松", city: city, description: "上海国际马拉松赛事", tracks: [
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
                    Event(eventIndex: 1, name: "上海城市定向赛", city: city, description: "上海城市定向挑战赛", tracks: [
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
                    Event(eventIndex: 0, name: "广州马拉松", city: city, description: "广州国际马拉松赛事", tracks: [
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
                    Event(eventIndex: 0, name: "深圳马拉松", city: city, description: "深圳国际马拉松赛事", tracks: [
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
                    Event(eventIndex: 1, name: "深圳湾跑步赛", city: city, description: "深圳湾公园跑步挑战赛", tracks: [
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
                    Event(eventIndex: 0, name: "未知马拉松", city: city, description: "未知马拉松赛事", tracks: [
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
            return
        }
        tracks = events[eventIndex].tracks
        selectedTrackIndex = 0 // 重置为第一个赛道
    }
    
    func createTeam(for trackIndex: Int) {
        guard !events.isEmpty && selectedEventIndex < events.count else {
            print("没有可用的赛事数据")
            return
        }
        
        let event = events[selectedEventIndex]
        guard trackIndex >= 0 && trackIndex < event.tracks.count else {
            print("没有可用的赛道数据或赛道索引无效: \(trackIndex)")
            return
        }
        
        let track = event.tracks[trackIndex]
        
        // 这里添加创建队伍的逻辑，例如显示创建队伍的表单或直接创建
        print("创建队伍: 赛事[\(event.name)], 赛道[\(track.name)]")
        
        // 模拟网络请求
        // 实际应用中，这里应该发送请求到服务器创建队伍
    }

    func joinTeam(for trackIndex: Int) {
        guard !events.isEmpty && selectedEventIndex < events.count else {
            print("没有可用的赛事数据")
            return
        }
        
        let event = events[selectedEventIndex]
        guard trackIndex >= 0 && trackIndex < event.tracks.count else {
            print("没有可用的赛道数据或赛道索引无效: \(trackIndex)")
            return
        }
        
        let track = event.tracks[trackIndex]
        
        // 这里添加加入队伍的逻辑，例如显示可用队伍列表
        print("加入队伍: 赛事[\(event.name)], 赛道[\(track.name)]")
        
        // 模拟网络请求
        // 实际应用中，这里应该发送请求到服务器获取可用队伍列表
    }
}

class PVPTrainingViewModel: ObservableObject {
    /*@Published var sport: SportName
    var category: SportCategory { sport.category }
    
    init(sport: SportName) {
        self.sport = sport
    }*/
}

class RVRTrainingViewModel: ObservableObject {
    /*@Published var sport: SportName
    var category: SportCategory { sport.category }
    
    init(sport: SportName) {
        self.sport = sport
    }*/
}

class RVRCompetitionViewModel: ObservableObject {
    /*@Published var sport: SportName
    
    var category: SportCategory { sport.category }
    
    init(sport: SportName) {
        self.sport = sport
    }*/
}

class PVPCompetitionViewModel: ObservableObject {
    /*@Published var sport: SportName
    var category: SportCategory { sport.category }
    
    init(sport: SportName) {
        self.sport = sport
    }*/
}
