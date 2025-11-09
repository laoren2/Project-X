//
//  WatchDataManager.swift
//  sportsx
//
//  apple watch 目前测试无法支持磁力计数据获取
//
//  Created by 任杰 on 2025/1/29.
//

import HealthKit
import WatchKit
import CoreMotion
import WatchConnectivity
import os

class WatchDataManager: NSObject, ObservableObject {
    static let shared = WatchDataManager()
    
    @Published var running = false
    
    @Published var heartRate: Double = 0
    private var avgHeartRate: Double = 0
    private var totalEnergy: Double = 0
    private var avgPower: Double = 0
    private var latestHeartRate: Double = 0
    private var latestPower: Double = 0
    var enableIMU: Bool = false
    
    @Published var showingAuthToast: Bool = false
    @Published var isNeedWaitingAuth: Bool = false
    
    @Published var showingSummaryView: Bool = false
    @Published var summaryViewData: SummaryViewData? = nil
    //@Published var workout: HKWorkout?
    
    private var lastSummarySent: SummaryData? = nil
    //private var timerTickCount: Int = 0
    
    private let motionManager = CMMotionManager()
    private let updateInterval = 1.0 / 20.0  // 20Hz
    
    private var sensorBuffer: [SensorDataItem] = []
    
    private var timer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.sportsx.watch.timer", qos: .userInitiated)
    
    // WatchConnectivity
    private let session = WCSession.default
    let healthStore = HKHealthStore()
    private var WKsession: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?
    
    private override init() {
        super.init()
        
        // 配置 session
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    func syncStatus() {
        let context = session.receivedApplicationContext
        guard !context.isEmpty else {
            //print("syncStatus: no context received yet.")
            return
        }
        
        if let command = context["command"] as? String, command == "startCollection" {
            if let ts = context["timestamp"] as? Double {
                let now = Date().timeIntervalSince1970
                if abs(now - ts) > 30 {
                    //print("syncStatus: context expired (timestamp \(ts), now \(now)), skipping startCollection.")
                    return
                }
            }
            let activityType = context["activityType"] as? String ?? "bike"
            let locationType = context["locationType"] as? String ?? "outdoor"
            // 动态配置运动类型
            let configuration = HKWorkoutConfiguration()
            switch activityType.lowercased() {
            case "running":
                configuration.activityType = .running
            case "bike":
                configuration.activityType = .cycling
            default:
                configuration.activityType = .other
            }
            configuration.locationType = (locationType.lowercased() == "indoor") ? .indoor : .outdoor
            enableIMU = context["enableIMU"] as? Bool ?? false
            //print("syncStatus: forcing start collection, type=\(activityType), location=\(locationType)")
            DispatchQueue.main.async {
                self.tryStartWorkout(config: configuration)
            }
        } else {
            print("syncStatus: no startCollection command in context.")
        }
    }
    
    // check and request authorization to access HealthKit.
    func checkHealthAuthorization(completion: @escaping (Bool) -> Void) {
        let typesToShare: Set<HKSampleType> = [
            HKQuantityType.workoutType()
        ]

        let typesToRead: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .cyclingPower)!
        ]

        // 合并需要检查的类型
        let allTypes: [HKObjectType] = Array(typesToShare) + Array(typesToRead)

        // 是否有未申请过的
        let needRequest = allTypes.contains {
            healthStore.authorizationStatus(for: $0) == .notDetermined
        }

        if needRequest {
            // 只要有一个没申请过，就触发系统弹窗
            healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
                guard success, error == nil else {
                    completion(false)
                    return
                }
                DispatchQueue.main.async {
                    self.isNeedWaitingAuth = true
                    self.showingAuthToast = true
                }
                // 每隔1s循环检查写入权限，最多尝试5次
                let maxTries = 5
                func checkWriteAuthorization(attempt: Int) {
                    let writeAuthorized = typesToShare.allSatisfy {
                        self.healthStore.authorizationStatus(for: $0) == .sharingAuthorized
                    }
                    if writeAuthorized {
                        completion(true)
                        return
                    }
                    if attempt >= maxTries {
                        completion(false)
                        return
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        checkWriteAuthorization(attempt: attempt + 1)
                    }
                }
                checkWriteAuthorization(attempt: 1)
            }
        } else {
            // 已经弹过了 → 判断是否都授权
            let writeAuthorized = typesToShare.allSatisfy {
                healthStore.authorizationStatus(for: $0) == .sharingAuthorized
            }
            completion(writeAuthorized)
        }
    }
    
    func tryStartWorkout(config: HKWorkoutConfiguration) {
        // 检查权限
        checkHealthAuthorization() { authorized in
            DispatchQueue.main.async {
                if authorized {
                    self.showingAuthToast = false
                    self.showingSummaryView = false
                    self.startWorkout(config: config)
                } else {
                    // 已经拒绝过，提示用户去设置里开
                    self.isNeedWaitingAuth = false
                    self.showingAuthToast = true
                }
            }
        }
    }
    
    func startWorkout(config: HKWorkoutConfiguration) {
        guard !running, WKsession == nil, builder == nil else { return }
        
        do {
            WKsession = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            builder = WKsession?.associatedWorkoutBuilder()
        } catch {
            // Handle any exceptions.
            print("WKsession create error")
            return
        }
        
        WKsession?.delegate = self
        builder?.delegate = self
        
        builder?.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: config
        )
        
        // Start the workout session and begin data collection.
        let startDate = Date()
        WKsession?.startActivity(with: startDate)
        builder?.beginCollection(withStart: startDate) { (success, error) in
            // The workout has started.
            //print("beginCollection success: \(success) error: \(error)")
            guard success, error == nil else { return }
            self.startCollecting()
        }
    }
    
    func startCollecting() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = updateInterval
            motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical)
        } else {
            print("DeviceMotion service not available on AW")
        }
        
        // 用 Timer 每 1/20s 取一次数据，存入 buffer，并每3秒发送一次 SummaryData
        timer?.cancel()  // 防止重复创建
        timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer?.schedule(deadline: .now(), repeating: updateInterval)
        
        var timerTickCount: Int = 0
        timer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            timerTickCount += 1
            
            if self.enableIMU {
                let zone = NSTimeZone.system
                let timeInterval = zone.secondsFromGMT()
                let dateNow = Date().addingTimeInterval(TimeInterval(timeInterval))
                
                if let data = self.motionManager.deviceMotion {
                    let item = SensorDataItem(
                        timestamp: dateNow,
                        accX: data.userAcceleration.x,
                        accY: data.userAcceleration.y,
                        accZ: data.userAcceleration.z,
                        gyroX: data.rotationRate.x,
                        gyroY: data.rotationRate.y,
                        gyroZ: data.rotationRate.z
                    )
                    self.sensorBuffer.append(item)
                } else {
                    print("device motion data not available")
                }
                
                // 如果 buffer 达到 20 条(1秒数据), 立即发送给 iPhone
                if self.sensorBuffer.count >= 20 {
                    //print("Send data to phone...")
                    self.sendBufferToiPhone()
                }
            }
            // 每3秒发送一次 SummaryData
            if timerTickCount >= 60 {
                timerTickCount = 0
                let currentSummary = SummaryData(
                    avgHeartRate: self.avgHeartRate,
                    totalEnergy: self.totalEnergy,
                    avgPower: self.avgPower,
                    latestHeartRate: self.latestHeartRate,
                    latestPower: self.latestPower
                )
                
                // incremental detection: only send if values changed significantly
                if self.shouldSendSummary(currentSummary) {
                    //print("Send summary data to phone...")
                    self.sendSummaryToiPhone(currentSummary)
                    self.lastSummarySent = currentSummary
                }
            }
        }
        timer?.resume()
    }
    
    private func shouldSendSummary(_ newSummary: SummaryData) -> Bool {
        guard let last = lastSummarySent else {
            return true
        }
        // Define thresholds for significant change
        let hrThreshold = 1.0
        let energyThreshold = 1.0
        let powerThreshold = 1.0
        let latestHrThreshold = 1.0
        let latestPowerThreshold = 1.0
        
        if abs(newSummary.avgHeartRate - last.avgHeartRate) > hrThreshold {
            return true
        }
        if abs(newSummary.totalEnergy - last.totalEnergy) > energyThreshold {
            return true
        }
        if abs(newSummary.avgPower - last.avgPower) > powerThreshold {
            return true
        }
        if abs(newSummary.latestHeartRate - last.latestHeartRate) > latestHrThreshold {
            return true
        }
        if abs(newSummary.latestPower - last.latestPower) > latestPowerThreshold {
            return true
        }
        return false
    }
    
    private func sendSummaryToiPhone(_ summary: SummaryData) {
        guard session.isReachable else {
            print("Session not reachable, statsData buffer send failed")
            return
        }
        
        let summaryDict: [String: Any] = [
            "avgHeartRate": summary.avgHeartRate,
            "totalEnergy": summary.totalEnergy,
            "avgPower": summary.avgPower,
            "latestHeartRate": summary.latestHeartRate,
            "latestPower": summary.latestPower
        ]
        
        session.sendMessage(["statsData": summaryDict], replyHandler: nil) { error in
            print("Error sending summaryData: \(error.localizedDescription)")
        }
    }
    
    func stopCollecting() {
        timer?.setEventHandler(handler: nil)
        timer?.cancel()
        timer = nil
        
        if motionManager.isDeviceMotionAvailable {
            motionManager.stopDeviceMotionUpdates()
        }
        
        // 比赛结束的数据快照兜底
        /*if summaryViewData == nil {
            summaryViewData = SummaryViewData(
                avgHeartRate: avgHeartRate,
                totalEnergy: totalEnergy,
                avgPower: avgPower,
                totalTime: workout?.duration ?? 0
            )
        }*/
        WKsession?.end()
        showingSummaryView = true
        //resetWorkout()
    }
    
    private func sendBufferToiPhone() {
        guard session.isReachable else {
            // isReachable 表示 iPhone 当前与 Watch App 前台可直连
            print("Session not reachable, send imu buffer failed")
            return
        }
        
        // 将 buffer 转为 [[String: Any]]
        let batch = sensorBuffer.map { item -> [String: Any] in
            return [
                "timestamp": item.timestamp,
                "accX": item.accX,
                "accY": item.accY,
                "accZ": item.accZ,
                "gyroX": item.gyroX,
                "gyroY": item.gyroY,
                "gyroZ": item.gyroZ
            ]
        }
        
        // 发送
        session.sendMessage(["IMUBatch": batch], replyHandler: nil) { error in
            print("Error sending watchBatch: \(error.localizedDescription)")
        }
        
        // 清空 buffer
        sensorBuffer.removeAll()
    }
    
    func updateForStatistics(_ statistics: HKStatistics?) {
        guard let statistics = statistics else { return }

        DispatchQueue.main.async {
            switch statistics.quantityType {
            case HKQuantityType.quantityType(forIdentifier: .heartRate):
                let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                self.latestHeartRate = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit) ?? 0
                self.heartRate = self.latestHeartRate
                self.avgHeartRate = statistics.averageQuantity()?.doubleValue(for: heartRateUnit) ?? 0
            case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                let unit = HKUnit.kilocalorie()
                self.totalEnergy = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                
            case HKQuantityType.quantityType(forIdentifier: .cyclingPower):
                let unit = HKUnit.watt()
                self.latestPower = statistics.mostRecentQuantity()?.doubleValue(for: unit) ?? 0
                self.avgPower = statistics.averageQuantity()?.doubleValue(for: unit) ?? 0
                /*case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                 let energyUnit = HKUnit.kilocalorie()
                 self.activeEnergy = statistics.sumQuantity()?.doubleValue(for: energyUnit) ?? 0
                 case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning), HKQuantityType.quantityType(forIdentifier: .distanceCycling):
                 let meterUnit = HKUnit.meter()
                 self.distance = statistics.sumQuantity()?.doubleValue(for: meterUnit) ?? 0*/
            default:
                return
            }
        }
    }
    
    func resetWorkout() {
        builder = nil
        WKsession = nil
        //workout = nil
        heartRate = 0
        avgHeartRate = 0
        totalEnergy = 0
        avgPower = 0
        latestHeartRate = 0
        latestPower = 0
        enableIMU = false
        //summaryViewData = nil
    }
}

// MARK: - WCSessionDelegate
extension WatchDataManager: WCSessionDelegate {
    // 激活回调
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("Watch session activationDidComplete: \(activationState.rawValue), error: \(String(describing: error))")
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        if let command = applicationContext["command"] as? String, command == "startCollection" {
            if let ts = applicationContext["timestamp"] as? Double {
                let now = Date().timeIntervalSince1970
                if abs(now - ts) > 30 {
                    //print("syncStatus: context expired (timestamp \(ts), now \(now)), skipping startCollection.")
                    return
                }
            }
            enableIMU = applicationContext["enableIMU"] as? Bool ?? false
            //print(("Set enableIMU to \(enableIMU)"))
        }
        if let command = applicationContext["command"] as? String, command == "stopCollection" {
            if let ts = applicationContext["timestamp"] as? Double {
                let now = Date().timeIntervalSince1970
                if abs(now - ts) > 30 {
                    //print("syncStatus: context expired (timestamp \(ts), now \(now)), skipping stopCollection.")
                    return
                }
            }
            //print("stop collecting...")
            DispatchQueue.main.async {
                self.stopCollecting()
            }
        }
    }
    
    // 收到 iPhone 端消息
    /*func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let command = message["command"] as? String, command == "stopCollection" {
            if running {
                print("stop collecting...")
                DispatchQueue.main.async {
                    self.showingSummaryView = true
                    self.stopCollecting()
                }
                WKsession?.end()
            }
        }
    }*/
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable {
            print("[AppleWatchDevice] Watch is now reachable.")
        } else {
            print("[AppleWatchDevice] Watch is no longer reachable.")
        }
    }
    
    // 其他回调可按需实现，比如后台发送或 transferFile/transferUserInfo
}

// MARK: - HKWorkoutSessionDelegate
extension WatchDataManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {
        DispatchQueue.main.async {
            self.running = toState == .running
        }
        
        if toState == .running {
            print("WKsession state change to running")
        }

        // Wait for the session to transition states before ending the builder.
        if toState == .ended {
            print("WKsession state change to end")
            builder?.endCollection(withEnd: date) { (success, error) in
                //print("endCollection success: \(success) error: \(error)")
                guard success, error == nil else { return }
                self.builder?.finishWorkout { (workout, error) in
                    guard error == nil, let workout = workout else {
                        print("finishWorkout error: \(String(describing: error))")
                        return
                    }
                    DispatchQueue.main.async {
                        // 从 workout 中获取系统统计
                        let energyStats = workout.statistics(for: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!)
                        let energy = energyStats?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                        let distance = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
                        let duration = workout.duration
                        
                        self.summaryViewData = SummaryViewData(
                            avgHeartRate: self.avgHeartRate,
                            totalEnergy: energy > 0 ? energy : self.totalEnergy,
                            avgPower: self.avgPower,
                            distance: distance,
                            totalTime: duration
                        )
                        
                        //self.workout = workout
                        //self.showingSummaryView = true
                        
                        // 清理资源
                        self.resetWorkout()
                    }
                }
            }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("WKsession error")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension WatchDataManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
    }

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { return }

            let statistics = workoutBuilder.statistics(for: quantityType)

            // Update the published values.
            updateForStatistics(statistics)
        }
    }
}

// 一个简单的传感器数据 item
struct SensorDataItem {
    let timestamp: Date
    let accX: Double
    let accY: Double
    let accZ: Double
    let gyroX: Double
    let gyroY: Double
    let gyroZ: Double
}

struct SummaryViewData {
    let avgHeartRate: Double
    let totalEnergy: Double
    let avgPower: Double
    let distance: Double
    let totalTime: TimeInterval
}

struct SummaryData {
    let avgHeartRate: Double
    let totalEnergy: Double
    let avgPower: Double
    let latestHeartRate: Double
    let latestPower: Double
}
