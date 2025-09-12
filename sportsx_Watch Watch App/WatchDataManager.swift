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
    @Published var running = false
    
    @Published var heartRate: Double = 0
    private var avgHeartRate: Double = 0
    private var totalEnergy: Double = 0
    private var avgPower: Double = 0
    private var latestHeartRate: Double = 0
    private var latestPower: Double = 0
    var enableIMU: Bool = false
    
    @Published var showingSummaryView: Bool = false
    @Published var summaryViewData: SummaryViewData? = nil
    //@Published var workout: HKWorkout?
    
    private var lastSummarySent: SummaryData? = nil
    //private var timerTickCount: Int = 0
    
    private let motionManager = CMMotionManager()
    private let updateInterval = 1.0 / 20.0  // 20Hz
    
    private var sensorBuffer: [SensorDataItem] = []
    private var bufferTimer: Timer?
    
    // WatchConnectivity
    private let session = WCSession.default
    let healthStore = HKHealthStore()
    private var WKsession: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?
    
    override init() {
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
            Logger.competition.notice_public("syncStatus: no context received yet.")
            return
        }
        
        if let command = context["command"] as? String, command == "startCollection" {
            if let ts = context["timestamp"] as? Double {
                let now = Date().timeIntervalSince1970
                if abs(now - ts) > 30 {
                    Logger.competition.notice_public("syncStatus: context expired (timestamp \(ts), now \(now)), skipping startCollection.")
                    return
                }
            }
            let activityType = context["activityType"] as? String ?? "bike"
            let locationType = context["locationType"] as? String ?? "outdoor"
            enableIMU = context["enableIMU"] as? Bool ?? false
            Logger.competition.notice_public("syncStatus: forcing start collection, type=\(activityType), location=\(locationType)")
            DispatchQueue.main.async {
                self.startWorkout(activityType: activityType, locationType: locationType)
                self.startCollecting()
            }
        } else {
            Logger.competition.notice_public("syncStatus: no startCollection command in context.")
        }
    }
    
    // Request authorization to access HealthKit.
    func requestAuthorization() {
        // The quantity type to write to the health store.
        let typesToShare: Set = [
            HKQuantityType.workoutType()
        ]
        
        // The quantity types to read from the health store.
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .cyclingPower)!
            //HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            //HKQuantityType.quantityType(forIdentifier: .distanceCycling)!,
            //HKObjectType.activitySummaryType()
        ]
        
        // Request authorization for those quantity types.
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { (success, error) in
            // Handle error.
        }
    }
    
    func startWorkout(activityType: String, locationType: String) {
        guard !running, WKsession == nil, builder == nil else { return }
        let configuration = HKWorkoutConfiguration()
        
        // 动态配置运动类型
        switch activityType.lowercased() {
        case "running":
            configuration.activityType = .running
        case "bike":
            configuration.activityType = .cycling
        default:
            configuration.activityType = .other
        }
        
        // 室内/室外
        configuration.locationType = (locationType.lowercased() == "indoor") ? .indoor : .outdoor
        
        do {
            WKsession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = WKsession?.associatedWorkoutBuilder()
        } catch {
            // Handle any exceptions.
            Logger.competition.notice_public("WKsession create error")
            return
        }
        
        WKsession?.delegate = self
        builder?.delegate = self
        
        builder?.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )
        
        // Start the workout session and begin data collection.
        let startDate = Date()
        WKsession?.startActivity(with: startDate)
        builder?.beginCollection(withStart: startDate) { (success, error) in
            // The workout has started.
        }
    }
    
    func startCollecting() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = updateInterval
            motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical)
        } else {
            Logger.competition.notice_public("DeviceMotion service not available on AW")
        }
        
        // 用 Timer 每 1/20s 取一次数据，存入 buffer，并每3秒发送一次 SummaryData
        var timerTickCount: Int = 0
        bufferTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            guard let self = self else {
                return
            }
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
                    Logger.competition.notice_public("device motion data not available")
                }
                
                // 如果 buffer 达到 20 条(1秒数据), 立即发送给 iPhone
                if self.sensorBuffer.count >= 20 {
                    Logger.competition.notice_public("Send data to phone...")
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
                    Logger.competition.notice_public("Send summary data to phone...")
                    self.sendSummaryToiPhone(currentSummary)
                    self.lastSummarySent = currentSummary
                }
            }
        }
        RunLoop.current.add(bufferTimer!, forMode: .default)
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
            Logger.competition.notice_public("Session not reachable, statsData buffer send failed")
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
            Logger.competition.notice_public("Error sending summaryData: \(error.localizedDescription)")
        }
    }
    
    func stopCollecting() {
        if self.bufferTimer != nil {
            self.bufferTimer?.invalidate()
            self.bufferTimer = nil
        }
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
            Logger.competition.notice_public("Session not reachable, send imu buffer failed")
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
            Logger.competition.notice_public("Error sending watchBatch: \(error.localizedDescription)")
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
        Logger.competition.notice_public("Watch session activationDidComplete: \(activationState.rawValue), error: \(String(describing: error))")
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        if let command = applicationContext["command"] as? String, command == "startCollection" {
            if let ts = applicationContext["timestamp"] as? Double {
                let now = Date().timeIntervalSince1970
                if abs(now - ts) > 30 {
                    Logger.competition.notice_public("syncStatus: context expired (timestamp \(ts), now \(now)), skipping startCollection.")
                    return
                }
            }
            let activityType = applicationContext["activityType"] as? String ?? "bike"
            let locationType = applicationContext["locationType"] as? String ?? "outdoor"
            enableIMU = applicationContext["enableIMU"] as? Bool ?? false
            Logger.competition.notice_public("Start collecting... type=\(activityType), location=\(locationType)")
            DispatchQueue.main.async {
                self.startWorkout(activityType: activityType, locationType: locationType)
                self.startCollecting()
            }
        }
        if let command = applicationContext["command"] as? String, command == "stopCollection" {
            if let ts = applicationContext["timestamp"] as? Double {
                let now = Date().timeIntervalSince1970
                if abs(now - ts) > 30 {
                    Logger.competition.notice_public("syncStatus: context expired (timestamp \(ts), now \(now)), skipping stopCollection.")
                    return
                }
            }
            Logger.competition.notice_public("stop collecting...")
            DispatchQueue.main.async {
                self.stopCollecting()
            }
        }
    }
    
    // 收到 iPhone 端消息
    /*func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let command = message["command"] as? String, command == "stopCollection" {
            if running {
                Logger.competition.notice_public("stop collecting...")
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
            Logger.competition.notice_public("[AppleWatchDevice] Watch is now reachable.")
        } else {
            Logger.competition.notice_public("[AppleWatchDevice] Watch is no longer reachable.")
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
            Logger.competition.notice_public("WKsession state change to running")
        }

        // Wait for the session to transition states before ending the builder.
        if toState == .ended {
            Logger.competition.notice_public("WKsession state change to end")
            builder?.endCollection(withEnd: date) { (success, error) in
                self.builder?.finishWorkout { (workout, error) in
                    guard error == nil, let workout = workout else {
                        Logger.competition.notice_public("finishWorkout error: \(String(describing: error))")
                        return
                    }
                    
                    DispatchQueue.main.async {
                        // 从 workout 中获取系统统计
                        let energyStats = workout.statistics(for: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!)
                        let energy = energyStats?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                        let distance = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
                        let duration = workout.duration
                        
                        // 用你在 updateForStatistics 中维护的 avg 值兜底
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
        Logger.competition.notice_public("WKsession error")
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
