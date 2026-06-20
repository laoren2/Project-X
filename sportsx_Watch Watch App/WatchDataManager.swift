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
import CoreLocation


enum SportType: String {
    case Bike = "bike"
    case Running = "running"
}

// 运动 mode：由手机握手时下发，决定手表实时页展示哪些元素
enum WorkoutMode: String {
    case race
    case routeTraining = "route_training"
    case freeTraining = "free_training"

    var isPaceCompare: Bool { self == .race || self == .routeTraining }
}

// 附近的奖励网格（手机推送，手表用经纬度本地算方位/距离）
struct WatchGrid: Identifiable {
    var id: String { "\(gridX),\(gridY)" }
    let gridX: Int
    let gridY: Int
    let lat: Double
    let lon: Double
    let reward: String      // 奖励类型（图标名）
    let count: Int
}

// 手机→手表实时负载（race/route：pace 预测 + PB 对比；free：周围 buff 网格）
struct WatchLivePayload {
    // race / route training
    var rank: Int? = nil
    var total: Int = 0
    var pbDeltaTime: Double? = nil       // 秒，>0 领先
    var pbDeltaDistance: Double? = nil   // 米，>0 领先
    var hasPB: Bool = false
    var locked: Bool = true              // 非订阅用户：手表侧同样以 -- 打码

    // free training
    var grids: [WatchGrid] = []
}

class WatchDataManager: NSObject, ObservableObject {
    static let shared = WatchDataManager()
    
    @Published var isRecording = false
    
    // 实时统计：对 View 只读发布（manager 内部仍可写），供 MetricsView 统计页展示
    @Published var heartRate: Double = 0
    @Published private(set) var avgHeartRate: Double = 0
    @Published private(set) var totalEnergy: Double = 0
    @Published private(set) var avgPower: Double? = nil
    @Published private(set) var latestPower: Double? = nil
    @Published private(set) var distance: Double = 0   // 累计距离（米），随运动类型取走路/跑步或骑行距离
    private var latestHeartRate: Double = 0

    private var lastStepDate: Date? = nil
    private var lastStepSnapshot: Double? = nil
    @Published private(set) var stepCadence: Double? = nil
    let stepThreshold: Double = 10.0

    @Published private(set) var cycleCadence: Double? = nil
    
    
    var enableIMU: Bool = false
    var sportType: SportType = .Bike

    // 当前 mode 与实时负载（供按 mode 分支渲染的实时页消费）
    @Published private(set) var workoutMode: WorkoutMode = .freeTraining
    @Published private(set) var live = WatchLivePayload()

    // 手表自身定位/朝向：free 雷达本地算方位/距离用
    @Published private(set) var currentLocation: CLLocation? = nil
    @Published private(set) var heading: CLHeading? = nil
    
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
    private let locationManager = CLLocationManager()
    private var routeBuilder: HKWorkoutRouteBuilder?
    
    private override init() {
        super.init()
        
        // 配置 session
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
        
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
    }
    
    func syncStatus() -> (result: Bool, msg: String) {
        let context = session.receivedApplicationContext
        guard !context.isEmpty else {
            //print("syncStatus: no context received yet.")
            return (false, "competition.applewatch.sync.failed.no_context")
        }
        
        if let command = context["command"] as? String, command == "startCollection" {
            if let ts = context["timestamp"] as? Double {
                let now = Date().timeIntervalSince1970
                if abs(now - ts) > 30 {
                    //print("syncStatus: context expired (timestamp \(ts), now \(now)), skipping startCollection.")
                    return (false, "competition.applewatch.sync.failed.expired")
                }
            }
            let activityType = context["activityType"] as? String ?? "bike"
            let locationType = context["locationType"] as? String ?? "outdoor"
            updateWorkoutMode(context["mode"] as? String)
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
            return (true, "")
        } else {
            //print("syncStatus: no startCollection command in context.")
            return (false, "competition.applewatch.sync.failed.no_context")
        }
    }
    
    // check and request authorization to access HealthKit.
    func checkHealthAuthorization(completion: @escaping (Bool) -> Void) {
        let typesToShare: Set<HKSampleType> = [
            HKQuantityType.workoutType(),
            HKSeriesType.workoutRoute()
        ]

        let typesToRead: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.runningPower),
            HKQuantityType(.cyclingPower),
            HKQuantityType(.cyclingCadence),
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType.workoutType(),
            HKSeriesType.workoutRoute()
        ]
        
        // 合并需要检查的类型
        //let allTypes: [HKObjectType] = Array(typesToShare) + Array(typesToRead)

        // 是否有未申请过的
        //let needRequest = allTypes.contains {
        //    healthStore.authorizationStatus(for: $0) == .notDetermined
        //}

        //if needRequest {
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
        //} else {
        //    // 已经弹过了 → 判断是否都授权
        //    let writeAuthorized = typesToShare.allSatisfy {
        //        healthStore.authorizationStatus(for: $0) == .sharingAuthorized
        //    }
        //    completion(writeAuthorized)
        //}
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
        guard !isRecording, WKsession == nil, builder == nil else { return }
        
        do {
            WKsession = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            builder = WKsession?.associatedWorkoutBuilder()
            routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: .local())
        } catch {
            // Handle any exceptions.
            print("WKsession create error")
            return
        }
        
        WKsession?.delegate = self
        builder?.delegate = self
        
        let dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: config
        )
        
        if config.activityType == .running {
            sportType = .Running
            dataSource.enableCollection(for: HKQuantityType(.stepCount), predicate: nil)
            dataSource.enableCollection(for: HKQuantityType(.distanceWalkingRunning), predicate: nil)
            dataSource.enableCollection(for: HKQuantityType(.runningPower), predicate: nil)
        }
        
        if config.activityType == .cycling {
            sportType = .Bike
            //dataSource.enableCollection(for: HKQuantityType(.cyclingCadence), predicate: nil)
            dataSource.enableCollection(for: HKQuantityType(.distanceCycling), predicate: nil)
            dataSource.enableCollection(for: HKQuantityType(.cyclingPower), predicate: nil)
        }
        
        builder?.dataSource = dataSource
        
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()   // free 雷达朝向用
        }

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
                
                // 长时间未更新则置零
                if let lastUpdate = self.lastStepDate, Date().timeIntervalSince(lastUpdate) > self.stepThreshold {
                    self.stepCadence = 0
                }
                
                let currentSummary = SummaryData(
                    avgHeartRate: self.avgHeartRate,
                    totalEnergy: self.totalEnergy,
                    avgPower: self.avgPower,
                    latestHeartRate: self.latestHeartRate,
                    latestPower: self.latestPower,
                    stepCadence: self.stepCadence,
                    cycleCadence: self.cycleCadence
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
        if let newAvgPower = newSummary.avgPower, let lastAvgPower = last.avgPower, abs(newAvgPower - lastAvgPower) > powerThreshold {
            return true
        }
        if abs(newSummary.latestHeartRate - last.latestHeartRate) > latestHrThreshold {
            return true
        }
        if let newPower = newSummary.latestPower, let lastPower = last.latestPower, abs(newPower - lastPower) > latestPowerThreshold {
            return true
        }
        return false
    }
    
    private func sendSummaryToiPhone(_ summary: SummaryData) {
        guard session.isReachable else {
            print("Session not reachable, statsData buffer send failed")
            return
        }
        
        var summaryDict: [String: Any] = [
            "avgHeartRate": summary.avgHeartRate,
            "totalEnergy": summary.totalEnergy,
            "latestHeartRate": summary.latestHeartRate
        ]
        
        if let avgPower = summary.avgPower {
            summaryDict["avgPower"] = avgPower
        }
        
        if let power = summary.latestPower {
            summaryDict["latestPower"] = power
        }
        
        if let stepCadence = summary.stepCadence {
            summaryDict["stepCadence"] = stepCadence
        }
        
        if let cycleCadence = summary.cycleCadence {
            summaryDict["cycleCadence"] = cycleCadence
        }
        
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
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        if isRecording {
            showingSummaryView = true
        }
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
            case HKQuantityType(.heartRate):
                let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                self.latestHeartRate = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit) ?? 0
                self.heartRate = self.latestHeartRate
                self.avgHeartRate = statistics.averageQuantity()?.doubleValue(for: heartRateUnit) ?? 0
            case HKQuantityType(.activeEnergyBurned):
                let unit = HKUnit.kilocalorie()
                self.totalEnergy = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
            case HKQuantityType(.runningPower):
                let unit = HKUnit.watt()
                self.latestPower = statistics.mostRecentQuantity()?.doubleValue(for: unit)
                self.avgPower = statistics.averageQuantity()?.doubleValue(for: unit)
            case HKQuantityType(.cyclingPower):
                let unit = HKUnit.watt()
                self.latestPower = statistics.mostRecentQuantity()?.doubleValue(for: unit)
                self.avgPower = statistics.averageQuantity()?.doubleValue(for: unit)
            case HKQuantityType(.stepCount):
                if let step = statistics.sumQuantity()?.doubleValue(for: .count()) {
                    if let last = self.lastStepSnapshot, let lastDate = self.lastStepDate {
                        let delta = step - last
                        self.stepCadence = 60 * delta / statistics.endDate.timeIntervalSince(lastDate)
                        //print("delta: \(delta) lastDate: \(lastDate) newDate: \(statistics.endDate)")
                        //print(self.stepCadence)
                    }
                    self.lastStepSnapshot = step
                    self.lastStepDate = statistics.endDate
                } else {
                    self.stepCadence = nil
                }
            case HKQuantityType(.cyclingCadence):
                self.cycleCadence = statistics.averageQuantity()?.doubleValue(for: .count())
            case HKQuantityType(.distanceWalkingRunning), HKQuantityType(.distanceCycling):
                // 累计距离（米），用于实时距离/配速/速度展示
                self.distance = statistics.sumQuantity()?.doubleValue(for: .meter()) ?? self.distance
            default:
                return
            }
        }
    }
    
    func resetWorkout() {
        routeBuilder = nil
        builder = nil
        WKsession = nil
        //workout = nil
        heartRate = 0
        avgHeartRate = 0
        totalEnergy = 0
        avgPower = nil
        latestHeartRate = 0
        latestPower = nil
        distance = 0
        live = WatchLivePayload()
        enableIMU = false
        stepCadence = nil
        cycleCadence = nil
        lastStepDate = nil
        lastStepSnapshot = nil
        lastSummarySent = nil
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
            updateWorkoutMode(applicationContext["mode"] as? String)
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
    
    // 收到 iPhone 端实时负载（race/route：pace 预测 + PB 对比；free：周围网格，后续接入）
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let live = message["live"] as? [String: Any] {
            applyLivePayload(live)
        }
    }

    // 解析 mode 握手；切换/开始时清空旧负载
    private func updateWorkoutMode(_ raw: String?) {
        let mode = raw.flatMap(WorkoutMode.init(rawValue:)) ?? .freeTraining
        DispatchQueue.main.async {
            self.workoutMode = mode
            self.live = WatchLivePayload()
        }
    }

    // 解析实时负载（缺省的可选键保持 nil → 展示 --）
    private func applyLivePayload(_ dict: [String: Any]) {
        var payload = WatchLivePayload()
        payload.rank = dict["rank"] as? Int
        payload.total = dict["total"] as? Int ?? 0
        payload.pbDeltaTime = dict["pbDeltaTime"] as? Double
        payload.pbDeltaDistance = dict["pbDeltaDistance"] as? Double
        payload.hasPB = dict["hasPB"] as? Bool ?? false
        payload.locked = dict["locked"] as? Bool ?? true
        if let rawGrids = dict["grids"] as? [[String: Any]] {
            payload.grids = rawGrids.compactMap { g in
                guard let gx = g["gx"] as? Int, let gy = g["gy"] as? Int,
                      let lat = g["lat"] as? Double, let lon = g["lon"] as? Double else { return nil }
                return WatchGrid(gridX: gx, gridY: gy, lat: lat, lon: lon,
                                 reward: g["reward"] as? String ?? "", count: g["count"] as? Int ?? 0)
            }
        }
        DispatchQueue.main.async {
            self.live = payload
        }
    }
    
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
            self.isRecording = toState == .running
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
                    self.routeBuilder?.finishRoute(with: workout, metadata: nil) { _, error in
                        if let error = error {
                            print("finishRoute error: \(error.localizedDescription)")
                        }
                    }
                    DispatchQueue.main.async {
                        // 从 workout 中获取系统统计
                        let stepStats = workout.statistics(for: HKQuantityType(.stepCount))
                        let stepCount = stepStats?.sumQuantity()?.doubleValue(for: .count())
                        let cycleStats = workout.statistics(for: HKQuantityType(.cyclingCadence))
                        let cycleCount = cycleStats?.averageQuantity()?.doubleValue(for: .count())
                        let energyStats = workout.statistics(for: HKQuantityType(.activeEnergyBurned))
                        let energy = energyStats?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                        let duration = workout.duration
                        let runningDistanceStats = workout.statistics(for: HKQuantityType(.distanceWalkingRunning))
                        let bikeDistanceStats = workout.statistics(for: HKQuantityType(.distanceCycling))
                        
                        self.summaryViewData = SummaryViewData(
                            avgHeartRate: self.avgHeartRate,
                            totalEnergy: energy > 0 ? energy : self.totalEnergy,
                            avgPower: self.avgPower,
                            distance: 0,
                            totalTime: duration,
                            stepCadence: nil,
                            cycleCadence: cycleCount
                        )
                        if let step = stepCount {
                            self.summaryViewData?.stepCadence = duration > 0 ? 60 * (step / duration) : nil
                        }
                        if self.sportType == .Running {
                            if let distance = runningDistanceStats?.sumQuantity()?.doubleValue(for: .meter()) {
                                self.summaryViewData?.distance = distance
                                // 清理资源
                                self.resetWorkout()
                            } else {
                                let predicate = HKQuery.predicateForSamples(
                                    withStart: workout.startDate,
                                    end: workout.endDate,
                                    options: .strictStartDate
                                )
                                let distanceType = HKQuantityType(.distanceWalkingRunning)
                                let distanceQuery = HKStatisticsQuery(
                                    quantityType: distanceType,
                                    quantitySamplePredicate: predicate,
                                    options: .cumulativeSum
                                ) { _, result, _ in
                                    let totalMeters = result?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                                    DispatchQueue.main.async {
                                        self.summaryViewData?.distance = totalMeters
                                        // 清理资源
                                        self.resetWorkout()
                                    }
                                }
                                self.healthStore.execute(distanceQuery)
                            }
                        } else if self.sportType == .Bike {
                            if let distance = bikeDistanceStats?.sumQuantity()?.doubleValue(for: .meter()) {
                                self.summaryViewData?.distance = distance
                                // 清理资源
                                self.resetWorkout()
                            } else {
                                let predicate = HKQuery.predicateForSamples(
                                    withStart: workout.startDate,
                                    end: workout.endDate,
                                    options: .strictStartDate
                                )
                                let distanceType = HKQuantityType(.distanceCycling)
                                let distanceQuery = HKStatisticsQuery(
                                    quantityType: distanceType,
                                    quantitySamplePredicate: predicate,
                                    options: .cumulativeSum
                                ) { _, result, _ in
                                    let totalMeters = result?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                                    DispatchQueue.main.async {
                                        self.summaryViewData?.distance = totalMeters
                                        // 清理资源
                                        self.resetWorkout()
                                    }
                                }
                                self.healthStore.execute(distanceQuery)
                            }
                        }
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

// MARK: - CLLocationManagerDelegate
extension WatchDataManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let latest = locations.last {
            DispatchQueue.main.async { self.currentLocation = latest }
        }
        guard let routeBuilder = routeBuilder else { return }
        // Filter the raw data.
        let filteredLocations = locations.filter { (location: CLLocation) -> Bool in
            location.horizontalAccuracy <= 50.0
        }
        guard !filteredLocations.isEmpty else { return }
        
        routeBuilder.insertRouteData(filteredLocations) { success, error in
            if let error = error {
                print("Route insert error: \(error.localizedDescription)")
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        DispatchQueue.main.async { self.heading = newHeading }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
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
    let avgPower: Double?
    var distance: Double
    let totalTime: TimeInterval
    var stepCadence: Double?
    let cycleCadence: Double?
}

struct SummaryData {
    let avgHeartRate: Double
    let totalEnergy: Double
    let avgPower: Double?
    let latestHeartRate: Double
    let latestPower: Double?
    let stepCadence: Double?
    let cycleCadence: Double?
}
