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


class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    private var lastDesiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyKilometer
    private var lastDistanceFilter: CLLocationDistance = kCLLocationAccuracyKilometer
    private var lastAllowsBackgroundLocationUpdates: Bool = false
    private var lastPausesLocationUpdatesAutomatically: Bool = true
    
    // 设备国家定位
    @Published var countryCode: String? = nil
    // 运动中心已选择的地区
    @Published var region: String? = nil
    
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
                let toast = Toast(message: "无位置信息权限")
                ToastManager.shared.show(toast: toast)
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
        //print("send location \(location)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager failed with error: \(error)")
    }
}
