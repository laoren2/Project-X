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
    @Published var showingSummaryView: Bool = false {
        didSet {
            // Sheet dismissed
            if showingSummaryView == false {
                resetWorkout()
            }
        }
    }
    @Published var workout: HKWorkout?
    //@Published var averageHeartRate: Double = 0
    
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
    
    // Request authorization to access HealthKit.
    func requestAuthorization() {
        // The quantity type to write to the health store.
        let typesToShare: Set = [
            HKQuantityType.workoutType()
        ]

        // The quantity types to read from the health store.
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            //HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            //HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            //HKQuantityType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.activitySummaryType()
        ]

        // Request authorization for those quantity types.
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { (success, error) in
            // Handle error.
        }
    }
    
    func startWorkout() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .badminton
        configuration.locationType = .indoor

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
            //motionManager.showsDeviceMovementDisplay = true
            motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical)
            if let data = motionManager.deviceMotion {
                Logger.competition.notice_public("Mag accuracy: \(data.magneticField.accuracy.rawValue)")
            }
            
            // 用 Timer 每 1/20s 取一次数据，存入 buffer
            bufferTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
                guard let self = self else {
                    return
                }
                
                var acceleration = CMAcceleration(x: 0, y: 0, z: 0)
                var gyro = CMRotationRate(x: 0, y: 0, z: 0)
                
                if let data = motionManager.deviceMotion {
                    acceleration = data.userAcceleration
                    gyro = data.rotationRate
                    //calibratedMagneticField = data.magneticField
                } else {
                    Logger.competition.notice_public("device motion data not available")
                }

                let zone = NSTimeZone.system
                let timeInterval = zone.secondsFromGMT()
                let dateNow = Date().addingTimeInterval(TimeInterval(timeInterval))
                
                let item = SensorDataItem(timestamp: dateNow,
                                          accX: acceleration.x,
                                          accY: acceleration.y,
                                          accZ: acceleration.z,
                                          gyroX: gyro.x,
                                          gyroY: gyro.y,
                                          gyroZ: gyro.z
                                          //magX: calibratedMagneticField.field.x,
                                          //magY: calibratedMagneticField.field.y,
                                          //magZ: calibratedMagneticField.field.z
                )
                
                self.sensorBuffer.append(item)
                
                // 如果 buffer 达到 20 条(1秒数据), 立即发送给 iPhone
                if self.sensorBuffer.count >= 20 {
                    Logger.competition.notice_public("Send data to phone...")
                    self.sendBufferToiPhone()
                }
            }
            RunLoop.current.add(bufferTimer!, forMode: .default)
        } else {
            Logger.competition.notice_public("DeviceMotion service not available on AW")
        }
    }
    
    func stopCollecting() {
        if self.bufferTimer != nil {
            self.bufferTimer?.invalidate()
            self.bufferTimer = nil
            
            if motionManager.isDeviceMotionAvailable {
                motionManager.stopDeviceMotionUpdates()
            }
        }
    }
    
    private func sendBufferToiPhone() {
        guard session.isReachable else {
            // isReachable 表示 iPhone 当前与 Watch App 前台可直连
            // 如果不可直连，可以使用 transferUserInfo 作为替代
            Logger.competition.notice_public("Session not reachable, consider using transferUserInfo")
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
                "gyroY": item.gyroZ,
                "gyroZ": item.gyroZ
                //"magX": item.magX,
                //"magY": item.magY,
                //"magZ": item.magZ
            ]
        }
        
        // 发送
        session.sendMessage(["watchBatch": batch], replyHandler: nil) { error in
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
                self.heartRate = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit) ?? 0
                //self.averageHeartRate = statistics.averageQuantity()?.doubleValue(for: heartRateUnit) ?? 0
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
        workout = nil
        heartRate = 0
    }
}

// MARK: - WCSessionDelegate
extension WatchDataManager: WCSessionDelegate {
    // 激活回调
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Logger.competition.notice_public("Watch session activationDidComplete: \(activationState.rawValue), error: \(String(describing: error))")
    }
    
    // 收到 iPhone 端消息
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let command = message["command"] as? String, command == "startCollection" {
            // iPhone 让Watch开始采集
            if !running {
                Logger.competition.notice_public("start collecting...")
                print("start collecting...")
                startWorkout()
                DispatchQueue.main.async {
                    self.startCollecting()
                }
            }
        } else if let command = message["command"] as? String, command == "stopCollection" {
            if running {
                Logger.competition.notice_public("stop collecting...")
                DispatchQueue.main.async {
                    self.showingSummaryView = true
                    self.stopCollecting()
                }
                WKsession?.end()
            }
        }
    }
    
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
                    DispatchQueue.main.async {
                        self.workout = workout
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
    //let magX: Double
    //let magY: Double
    //let magZ: Double
}

