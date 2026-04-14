//
//  LocationManager.swift
//  sportsx
//
//  全局单例 + Combine 模式管理Location的更新，不同场景 -> 不同更新策略
//
//  可能存在订阅/取消订阅失败的情况，例如频繁快速订阅/取消订阅
//  场景之一是在某些容器视图（例如scrollview）内子视图appear和disappear时进行订阅和取消订阅，此时可能会频繁调用，
//  可能导致出现增加无效的订阅，后期可以考虑使用全局锁来锁住订阅和取消订阅的全过程
//
//  Created by 任杰 on 2024/12/6.
//

import Foundation
import CoreLocation
import Combine
import SwiftUI


enum GPSStrength: String {
    case excellent, good, fair, poor, unknown
    
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .yellow
        case .fair: return .orange
        case .poor: return .red
        case .unknown: return .gray
        }
    }
    
    var bars: Int {
        switch self {
        case .excellent: return 4
        case .good: return 3
        case .fair: return 2
        case .poor: return 1
        case .unknown: return 0
        }
    }
}

struct Region: Identifiable, Equatable {
    var id: String { return regionID }
    let regionID: String
    let regionName: String
    
    static func == (lhs: Region, rhs: Region) -> Bool {
        return lhs.regionID == rhs.regionID
    }
}

// todo: 考虑统一放到服务端管理regions
let regionTable_CN: [String: [Region]] = [
    "region.cn.shanghai": [Region(regionID: "CN-SH-SH", regionName: "region.cn.shanghai")],
    "region.cn.beijing": [Region(regionID: "CN-BJ-BJ", regionName: "region.cn.beijing")],
    "region.cn.guangdong": [
        Region(regionID: "CN-GD-GZ", regionName: "region.cn.guangzhou"),
        Region(regionID: "CN-GD-SZ", regionName: "region.cn.shenzhen"),
        Region(regionID: "CN-GD-FS", regionName: "region.cn.foshan")
    ],
    "region.cn.zhejiang": [
        Region(regionID: "CN-ZJ-HZ", regionName: "region.cn.hangzhou"),
        Region(regionID: "CN-ZJ-WZ", regionName: "region.cn.wenzhou"),
        Region(regionID: "CN-ZJ-NB", regionName: "region.cn.ningbo")
    ],
    "region.cn.jiangsu": [
        Region(regionID: "CN-JS-NJ", regionName: "region.cn.nanjing"),
        Region(regionID: "CN-JS-SZ", regionName: "region.cn.suzhou"),
        Region(regionID: "CN-JS-WX", regionName: "region.cn.wuxi")
    ],
    "region.cn.anhui": [
        Region(regionID: "CN-AH-HF", regionName: "region.cn.hefei"),
        Region(regionID: "CN-AH-HS", regionName: "region.cn.huangshan")
    ]
]

let regionTable_HK: [String: [Region]] = [
    "region.hk.xianggangdao": [
        Region(regionID: "HK-SOUTHERN", regionName: "region.hk.nanqu"),
        Region(regionID: "HK-CENTRAL-AND-WESTERN", regionName: "region.hk.zhongxiqu"),
        Region(regionID: "HK-WAN-CHAI", regionName: "region.hk.wanzaiqu"),
        Region(regionID: "HK-EASTERN", regionName: "region.hk.dongqu")
    ],
    "region.hk.jiulong": [
        Region(regionID: "HK-KWUN-TONG", regionName: "region.hk.guantangqu"),
        Region(regionID: "HK-KOWLOON-CITY", regionName: "region.hk.jiulongchengqu"),
        Region(regionID: "HK-YAU-TSIM-MONG", regionName: "region.hk.youjianwangqu"),
        Region(regionID: "HK-SHAM-SHUI-PO", regionName: "region.hk.shenshuipo"),
        Region(regionID: "HK-WONG-TAI-SIN", regionName: "region.hk.huangdaxianqu")
    ],
    "region.hk.xinjie": [
        Region(regionID: "HK-NORTH", regionName: "region.hk.beiqu"),
        Region(regionID: "HK-ISLANDS", regionName: "region.hk.lidaoqu"),
        Region(regionID: "HK-TSUEN-WAN", regionName: "region.hk.quanwan"),
        Region(regionID: "HK-TAI-PO", regionName: "region.hk.dapuqu"),
        Region(regionID: "HK-SHA-TIN", regionName: "region.hk.shatianqu"),
        Region(regionID: "HK-SAI-KUNG", regionName: "region.hk.xigongqu"),
        Region(regionID: "HK-KWAI-TSING", regionName: "region.hk.kuiqingqu"),
        Region(regionID: "HK-TUEN-MUN", regionName: "region.hk.tunmenqu"),
        Region(regionID: "HK-YUEN-LONG", regionName: "region.hk.yuanlangqu")
    ]
]

let regionTable_TW: [String: [Region]] = [
    "region.tw.beiqu": [
        Region(regionID: "TW-TAI-PEI-CITY", regionName: "region.tw.taibei"),
        Region(regionID: "TW-NEW-TAI-PEI-CITY", regionName: "region.tw.xinbei"),
        Region(regionID: "TW-KEE-LUNG-CITY", regionName: "region.tw.jilong"),
        Region(regionID: "TW-TAO-YUAN", regionName: "region.tw.taoyuan"),
        Region(regionID: "TW-HSIN-CHU-CITY", regionName: "region.tw.xinzhushi"),
        Region(regionID: "TW-HSIN-CHU", regionName: "region.tw.xinzhu"),
        Region(regionID: "TW-YI-LAN", regionName: "region.tw.yilan")
    ],
    "region.tw.zhongqu": [
        Region(regionID: "TW-MIAO-LI", regionName: "region.tw.miaoli"),
        Region(regionID: "TW-TAI-CHUNG", regionName: "region.tw.taizhong"),
        Region(regionID: "TW-CHANG-HUA", regionName: "region.tw.zhanghua"),
        Region(regionID: "TW-NAN-TOU", regionName: "region.tw.nantou"),
        Region(regionID: "TW-YUN-LIN", regionName: "region.tw.yunlin")
    ],
    "region.tw.nanqu": [
        Region(regionID: "TW-CHIA-YI-CITY", regionName: "region.tw.jiayishi"),
        Region(regionID: "TW-CHIA-YI", regionName: "region.tw.jiayi"),
        Region(regionID: "TW-TAI-NAN-CITY", regionName: "region.tw.tainan"),
        Region(regionID: "TW-KAOH-SIUNG-CITY", regionName: "region.tw.gaoxiong"),
        Region(regionID: "TW-PING-TUNG", regionName: "region.tw.pingdong"),
        Region(regionID: "TW-PENG-HU", regionName: "region.tw.penghu")
    ],
    "region.tw.dongqu": [
        Region(regionID: "TW-TAI-TUNG", regionName: "region.tw.taidong"),
        Region(regionID: "TW-HUA-LIEN", regionName: "region.tw.hualian")
    ],
    "region.tw.waidao": [
        Region(regionID: "TW-KIN-MEN", regionName: "region.tw.jinmen"),
        Region(regionID: "TW-MATSU-ISLANDS", regionName: "region.tw.mazu")
    ]
]

let regionTable_KR: [String: [Region]] = [
    "region.kr.gongwan": [
        Region(regionID: "KR-GONG-WAN", regionName: "region.kr.gongwan")
    ],
    "region.kr.gyeonggi": [
        Region(regionID: "KR-GYEONG-GI", regionName: "region.kr.gyeonggi")
    ],
    "region.kr.southchungcheong": [
        Region(regionID: "KR-SOUTH-CHUNG-CHEONG", regionName: "region.kr.southchungcheong")
    ],
    "region.kr.incheon": [
        Region(regionID: "KR-IN-CHEON", regionName: "region.kr.incheon")
    ],
    "region.kr.northjeolla": [
        Region(regionID: "KR-NORTH-JEOLLA", regionName: "region.kr.northjeolla")
    ],
    "region.kr.southjeolla": [
        Region(regionID: "KR-SOUTH-JEOLLA", regionName: "region.kr.southjeolla")
    ],
    "region.kr.southgyeongsang": [
        Region(regionID: "KR-SOUTH-GYEONG-SANG", regionName: "region.kr.southgyeongsang")
    ],
    "region.kr.busan": [
        Region(regionID: "KR-BU-SAN", regionName: "region.kr.busan")
    ],
    "region.kr.ulsan": [
        Region(regionID: "KR-UL-SAN", regionName: "region.kr.ulsan")
    ],
    "region.kr.northgyeongsang": [
        Region(regionID: "KR-NORTH-GYEONG-SANG", regionName: "region.kr.northgyeongsang")
    ],
    "region.kr.jeju": [
        Region(regionID: "KR-JE-JU", regionName: "region.kr.jeju")
    ],
    "region.kr.seoul": [
        Region(regionID: "KR-SEO-UL", regionName: "region.kr.seoul")
    ],
    "region.kr.daejeon": [
        Region(regionID: "KR-DAE-JEON", regionName: "region.kr.daejeon")
    ],
    "region.kr.sejong": [
        Region(regionID: "KR-SE-JONG", regionName: "region.kr.sejong")
    ],
    "region.kr.northchungcheong": [
        Region(regionID: "KR-NORTH-CHUNG-CHEONG", regionName: "region.kr.northchungcheong")
    ],
    "region.kr.gwangju": [
        Region(regionID: "KR-GWANG-JU", regionName: "region.kr.gwangju")
    ],
    "region.kr.daegu": [
        Region(regionID: "KR-DAE-GU", regionName: "region.kr.daegu")
    ]
]

let regionTable_US: [String: [Region]] = [
    "region.us.northeast": [
        Region(regionID: "US-MAINE", regionName: "region.us.maine"),
        Region(regionID: "US-NEW-HAMPSHIRE", regionName: "region.us.newhampshire"),
        Region(regionID: "US-VERMONT", regionName: "region.us.vermont"),
        Region(regionID: "US-MASSACHUSETTS", regionName: "region.us.massachusetts"),
        Region(regionID: "US-RHODE-ISLAND", regionName: "region.us.rhodeisland"),
        Region(regionID: "US-CONNECTICUT", regionName: "region.us.connecticut"),
        Region(regionID: "US-NEW-YORK", regionName: "region.us.newyork"),
        Region(regionID: "US-NEW-JERSEY", regionName: "region.us.newjersey"),
        Region(regionID: "US-PENNSYLVANIA", regionName: "region.us.pennsylvania"),
        Region(regionID: "US-DELAWARE", regionName: "region.us.delaware"),
        Region(regionID: "US-MARYLAND", regionName: "region.us.maryland"),
        Region(regionID: "US-WASHINGTONDC", regionName: "region.us.washingtondc")
    ],
    "region.us.midwest": [
        Region(regionID: "US-OHIO", regionName: "region.us.ohio"),
        Region(regionID: "US-MICHIGAN", regionName: "region.us.michigan"),
        Region(regionID: "US-INDIANA", regionName: "region.us.indiana"),
        Region(regionID: "US-ILLINOIS", regionName: "region.us.illinois"),
        Region(regionID: "US-WISCONSIN", regionName: "region.us.wisconsin"),
        Region(regionID: "US-MINNESOTA", regionName: "region.us.minnesota"),
        Region(regionID: "US-IOWA", regionName: "region.us.iowa"),
        Region(regionID: "US-MISSOURI", regionName: "region.us.missouri"),
        Region(regionID: "US-NORTH-DAKOTA", regionName: "region.us.northdakota"),
        Region(regionID: "US-SOUTH-DAKOTA", regionName: "region.us.southdakota"),
        Region(regionID: "US-NEBRASKA", regionName: "region.us.nebraska"),
        Region(regionID: "US-KANSAS", regionName: "region.us.kansas")
    ],
    "region.us.southeast": [
        Region(regionID: "US-VIRGINIA", regionName: "region.us.virginia"),
        Region(regionID: "US-WEST-VIRGINIA", regionName: "region.us.westvirginia"),
        Region(regionID: "US-KENTUCKY", regionName: "region.us.kentucky"),
        Region(regionID: "US-NORTH-CAROLINA", regionName: "region.us.northcarolina"),
        Region(regionID: "US-SOUTH-CAROLINA", regionName: "region.us.southcarolina"),
        Region(regionID: "US-TENNESSEE", regionName: "region.us.tennessee"),
        Region(regionID: "US-GEORGIA", regionName: "region.us.georgia"),
        Region(regionID: "US-FLORIDA", regionName: "region.us.florida"),
        Region(regionID: "US-ALABAMA", regionName: "region.us.alabama"),
        Region(regionID: "US-MISSISSIPPI", regionName: "region.us.mississippi"),
        Region(regionID: "US-ARKANSAS", regionName: "region.us.arkansas"),
        Region(regionID: "US-LOUISIANA", regionName: "region.us.louisiana")
    ],
    "region.us.southwest": [
        Region(regionID: "US-TEXAS", regionName: "region.us.texas"),
        Region(regionID: "US-OKLAHOMA", regionName: "region.us.oklahoma"),
        Region(regionID: "US-NEW-MEXICO", regionName: "region.us.newmexico"),
        Region(regionID: "US-ARIZONA", regionName: "region.us.arizona")
    ],
    "region.us.west": [
        Region(regionID: "US-COLORADO", regionName: "region.us.colorado"),
        Region(regionID: "US-WYOMING", regionName: "region.us.wyoming"),
        Region(regionID: "US-MONTANA", regionName: "region.us.montana"),
        Region(regionID: "US-IDAHO", regionName: "region.us.idaho"),
        Region(regionID: "US-UTAH", regionName: "region.us.utah"),
        Region(regionID: "US-NEVADA", regionName: "region.us.nevada"),
        Region(regionID: "US-CALIFORNIA", regionName: "region.us.california"),
        Region(regionID: "US-OREGON", regionName: "region.us.oregon"),
        Region(regionID: "US-WASHINGTON", regionName: "region.us.washington"),
        Region(regionID: "US-ALASKA", regionName: "region.us.alaska"),
        Region(regionID: "US-HAWAII", regionName: "region.us.hawaii")
    ]
]

struct RegionStore {
    static let tables: [String: [String: [Region]]] = [
        "CN": regionTable_CN,
        "HK": regionTable_HK,
        "TW": regionTable_TW,
        "KR": regionTable_KR,
        "US": regionTable_US
    ]
    
    static let index: [String: Region] = {
        var dict: [String: Region] = [:]
        for (_, country) in tables {
            for (_, regions) in country {
                for r in regions {
                    dict[r.regionID] = r
                }
            }
        }
        return dict
    }()
}

enum RealNameMethod: String {
    case idcard = "idcard"
    case passport = "passport"
    case drivingLicense = "drivingLicense"
    
    var displayName: LocalizedStringKey {
        switch self {
        case .idcard: return "user.setup.realname_auth.method.idcard"
        case .passport: return "user.setup.realname_auth.method.passport"
        case .drivingLicense: return "user.setup.realname_auth.method.driving_license"
        }
    }
}

enum Country: String, CaseIterable {
    case hk = "HK"
    case tw = "TW"
    case kr = "KR"
    case cn = "CN"
    case us = "US"
    
    var supported: Bool {
        switch self {
        case .hk ,.tw, .kr, .us: return true
        case .cn: return false
        }
    }
    
    var phoneCode: String {
        switch self {
        case .hk: return "852"
        case .tw: return "886"
        case .kr: return "82"
        case .cn: return "86"
        case .us: return "1"
        }
    }
    
    var displayName: LocalizedStringKey {
        switch self {
        case .hk: return "region.hk"
        case .tw: return "region.tw"
        case .kr: return "region.kr"
        case .cn: return "region.cn"
        case .us: return "region.us"
        }
    }
    
    var phoneNumberLength: ClosedRange<Int> {
        switch self {
        case .hk: return 8...8
        case .tw: return 9...9
        case .kr: return 10...11
        case .cn: return 11...11
        case .us: return 10...10
        }
    }
    
    var realnameMethod: [RealNameMethod] {
        switch self {
        case .hk: return [.idcard, .passport]
        case .tw: return [.idcard, .passport]
        case .kr: return [.idcard, .passport]
        case .cn: return [.idcard]
        case .us: return [.drivingLicense, .passport]
        }
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    private var lastDesiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyKilometer
    private var lastDistanceFilter: CLLocationDistance = kCLLocationAccuracyKilometer
    private var lastAllowsBackgroundLocationUpdates: Bool = false
    private var lastPausesLocationUpdatesAutomatically: Bool = true
    
    // GPS信号强度
    @Published var signalStrength: GPSStrength = .unknown
    // 设备国家定位
    @Published var country: Country? = nil
    // 运动中心已选择的地区
    @Published var regionID: String? = nil
    var regionName: LocalizedStringKey? {
        guard let regionID = regionID, let region = RegionStore.index[regionID] else { return nil }
        return LocalizedStringKey(region.regionName)
    }
    
    // 使用 @Published 来发布授权状态变化
    @Published var authorizationStatus: CLAuthorizationStatus
    
    // 使用 PassthroughSubject 发布位置更新
    private let locationSubject = PassthroughSubject<CLLocation, Never>()
    
    // 订阅者计数及其锁，确保多线程安全
    private var subscribersCount = 0
    private let subscribersCountLock = NSLock()
    
    // 全局锁，防止可能存在某些未知特殊情况下的订阅/取消订阅失败
    //let testLock = NSLock()
    
    override private init() {
        // 初始化授权状态
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter = kCLLocationAccuracyKilometer
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.allowsBackgroundLocationUpdates = false
        // 注意：此时并不立即开始更新位置，等待订阅者出现后再启动
    }
    
    // 提供位置更新的Publisher
    func locationPublisher() -> AnyPublisher<CLLocation, Never> {
        // 利用 handleEvents 在订阅和取消订阅时动态启动/停止位置更新
        return locationSubject
            .handleEvents(
                receiveSubscription: { [weak self] _ in
                    //print("receiveSubscription")
                    self?.incrementSubscribers()
                },
                receiveCancel: { [weak self] in
                    //print("receiveCancel")
                    self?.decrementSubscribers()
                }
            )
            .share()
            .eraseToAnyPublisher()
    }
    
    // 提供授权状态的Publisher（可直接使用 $authorizationStatus）
    // 如果想要AnyPublisher则：
    func authorizationPublisher() -> AnyPublisher<CLAuthorizationStatus, Never> {
        $authorizationStatus.eraseToAnyPublisher()
    }
    
    // 检查准确位置权限
    func checkPreciseLocation() -> Bool {
        return locationManager.accuracyAuthorization == .fullAccuracy
    }
    
    private func incrementSubscribers() {
        subscribersCountLock.lock()
        subscribersCount += 1
        let count = subscribersCount
        subscribersCountLock.unlock()
        
        if count == 1 {
            // 第一个订阅者出现，开始位置更新（如果权限允许）
            startUpdatingLocationIfNeeded()
        }
        //print("incrementSubscribers - Thread: \(Thread.current)")
        //print("+count: ",count)
    }
    
    private func decrementSubscribers() {
        subscribersCountLock.lock()
        subscribersCount = max(subscribersCount - 1, 0)
        let count = subscribersCount
        subscribersCountLock.unlock()
        
        if count == 0 {
            // 没有订阅者了，停止位置更新以节省资源
            stopUpdatingLocation()
        }
        //print("decrementSubscribers - Thread: \(Thread.current)")
        //print("-count: ",count)
    }
    
    func startUpdatingLocationIfNeeded() {
        let status = locationManager.authorizationStatus
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            locationManager.startUpdatingLocation()
        } else if status == .notDetermined {
            // 请求WhenInUse权限
            locationManager.requestWhenInUseAuthorization()
        } else {
            // Denied或Restricted时无法启动更新
            DispatchQueue.main.async {
                PopupWindowManager.shared.presentPopup(
                    title: "competition.location_select.no_auth.popup.title",
                    message: "competition.location_select.no_auth.popup.content",
                    bottomButtons: [.confirm()]
                )
            }
        }
    }
    
    private func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    // 手动强制开始位置更新
    func startUpdating() {
        // 调用此方法时，可确保即使没有订阅者也开始更新位置（谨慎使用）
        locationManager.startUpdatingLocation()
    }
    
    // 手动强制停止位置更新
    func stopUpdating() {
        locationManager.stopUpdatingLocation()
    }
    
    // 手动请求一次位置更新
    func requestUpdateOnce() {
        locationManager.requestLocation()
    }
    
    func getLocation() -> CLLocation? {
        return locationManager.location
    }
    
    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func changeToLowUpdate() {
        //print("LowUpdate")
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter = kCLLocationAccuracyKilometer
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.allowsBackgroundLocationUpdates = false
    }
    
    func saveLowToLast() {
        lastDesiredAccuracy = kCLLocationAccuracyKilometer
        lastDistanceFilter = kCLLocationAccuracyKilometer
        lastPausesLocationUpdatesAutomatically = true
        lastAllowsBackgroundLocationUpdates = false
    }
    
    func changeToMediumUpdate() {
        //print("MediumUpdate")
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = true
    }
    
    func saveMediumToLast() {
        lastDesiredAccuracy = kCLLocationAccuracyBest
        lastDistanceFilter = kCLDistanceFilterNone
        lastPausesLocationUpdatesAutomatically = true
        lastAllowsBackgroundLocationUpdates = false
    }
    
    func changeToHighUpdate() {
        //print("HighUpdate")
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    func backToLastSet() {
        locationManager.desiredAccuracy = lastDesiredAccuracy
        locationManager.distanceFilter = lastDistanceFilter
        locationManager.pausesLocationUpdatesAutomatically = lastPausesLocationUpdatesAutomatically
        locationManager.allowsBackgroundLocationUpdates = lastAllowsBackgroundLocationUpdates
        //print("back to \(locationManager.desiredAccuracy)")
        //print("back to \(locationManager.allowsBackgroundLocationUpdates)")
    }
    
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            //print("didChangeAuthorization to : \(status)")
            self.authorizationStatus = status
            // 授权状态改变后，如果有订阅者，应再次检查是否可以启动更新
            if self.subscribersCount > 0 && (status == .authorizedAlways || status == .authorizedWhenInUse) {
                self.startUpdatingLocationIfNeeded()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        locationSubject.send(location)
        //print(locationManager.desiredAccuracy)
        //print(locationManager.allowsBackgroundLocationUpdates)
        DispatchQueue.main.async {
            let accuracy = location.horizontalAccuracy
            //print(accuracy)
            switch accuracy {
            case 0..<5:
                self.signalStrength = .excellent
            case 5..<10:
                self.signalStrength = .good
            case 10..<25:
                self.signalStrength = .fair
            case 25..<50:
                self.signalStrength = .poor
            default:
                self.signalStrength = .unknown
            }
        }
        //print("send location \(location)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager failed with error: \(error)")
    }
}
