//
//  CompetitionManager.swift
//  sportsx
//
//  全局的比赛引擎，管理和控制一场比赛的全过程
//
//  Created by 任杰 on 2024/9/7.
//

import SwiftUI
import CoreLocation
import CoreMotion
import AVFoundation
import Combine
import CoreML
import os

#if DEBUG
// phone原始数据保存到本地
var SAVEPHONERAWDATA: Bool = false

// sensor数据保存到本地
var SAVESENSORDATA: Bool = false

// 是否上传非真实比赛校验分数
let SKIPVARIFYSCOREUPLOAD: Bool = true

// 是否 dump 每场比赛的详细数据
let DUMPMATCHDATA: Bool = true
#endif

class CompetitionManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = CompetitionManager()
    
    let navigationManager = NavigationManager.shared
    let dataFusionManager = DataFusionManager.shared
    let modelManager = ModelManager.shared
    let deviceManager = DeviceManager.shared
    let userManager = UserManager.shared
    let globalConfig = GlobalConfig.shared
    let dailyTaskManager = DailyTaskManager.shared
    let assetManager = AssetManager.shared
    
    let eventBus = MatchEventBus()      // 比赛引擎的总线，负责比赛中事件的注册和通知
    let matchContext = MatchContext()   // 比赛进行中的上下文信息
    private var recentAltitudeSamples: [Double] = []
    private let altitudeSmoothingWindow = 5
    private let elevationThreshold = 1.5
    private var horizontalDistanceWindow = 0.0
    private var pendingElevationGain: Double = 0
    
    // 当前进行中的运动和记录
    var sport: SportName? { return sportFeature?.sportType }//= .Default
    var sportFeature: SportFeature? = nil
    var currentBikeRecord: BikeRaceRecord?
    var currentRunningRecord: RunningRaceRecord?
    var isTeam: Bool {
        switch sportFeature {
        case .bikeRace:
            return currentBikeRecord?.isTeam == true
        case .bikeRouteTraining:
            return false        // 暂不支持路线训练模式进行组队
        case .runningRace:
            return currentRunningRecord?.isTeam == true
        case .runningRouteTraining:
            return false
        default:
            return false
        }
    }
    var currentBikeRoute: BikeRouteEnv?
    var currentRunningRoute: RunningRouteEnv?
    
    // 下一个需要经过的检查点
    @Published var nextCheckPointIndex: Int?
    
    @Published var selectedCards: [MagicCard] = []
    var activeCardEffects: [MagicCardEffect] = []
    
    // 当前比赛需要绑定的传感器
    // | 00   +   +   +   +   +    +  |
    //        |   |   |   |   |    |
    //       WST  RF  LF  RH  LH  PHONE
    var sensorRequest: Int = 0
    
    @Published var isRecording: Bool = false // 当前比赛状态
    @Published var isShowWidget: Bool = false // 是否显示Widget
    
    @Published var showAlert = false // 是否弹出提示
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    @Published var userLocation: CLLocation? = nil // 当前用户位置
    @Published var isInValidArea: Bool = false // 是否在比赛出发点（routePoints[0] 检查区）

    private var motionManager: CMMotionManager = CMMotionManager()
    private var audioRecorder: AVAudioRecorder!
    private var startTime: Date?
    
#if DEBUG
    // 仅用于保存传感器数据到本地调试
    private var competitionData: [PhoneData] = []
    private let batchSize = 60 // 每次采集60条数据后写入文件
    
    var basePathData_debug: [PathPoint] = []
    var bikePathData_debug: [BikePathPoint] = []
    var runningPathData_debug: [RunningPathPoint] = []
    
    @Published var validationScore_debug: Double = 0
#endif
    
    @Published var basePathData: [PathPoint] = []                             // 基本轨迹数据
    @Published var bikePathData: [BikePathPoint] = []                         // bike竞赛轨迹数据
    @Published var runningPathData: [RunningPathPoint] = []                   // running竞赛轨迹数据
    private var pathPointInEndSafetyRadius: [PathPoint] = []                  // 在终点的安全范围内记录的点
    @Published var realtimeStatisticData: StatisticData = .empty              // 比赛时 realtimeView 展示的实时统计数据
    
    @Published var bikeFreeTrainingPathData: [BikeFreeTrainingPathPoint] = []           // bike自由训练轨迹数据
    @Published var runningFreeTrainingPathData: [RunningFreeTrainingPathPoint] = []     // running自由训练轨迹数据
    @Published var bikeRouteTrainingPathData: [BikeRouteTrainingPathPoint] = []           // bike路线训练轨迹数据
    @Published var runningRouteTrainingPathData: [RunningRouteTrainingPathPoint] = []     // running路线训练轨迹数据

    // MARK: - 运动中实时配速（预测完赛名次 + 与个人最佳对比），仅 race / route training
    var paceEstimator: RoutePaceEstimator? = nil
    private var lastPaceUpdate: Date = .distantPast
    @Published var pacePredictedRank: Int? = nil        // 预测完赛名次
    @Published var pacePredictedTotal: Int = 0          // 榜单规模
    @Published var paceHasPB: Bool = false              // 是否有个人最佳可对比
    @Published var paceDeltaTime: Double? = nil         // 与 PB 的时间差（秒，>0 领先）
    @Published var paceDeltaDistance: Double? = nil     // 与 PB 的距离差（米，>0 领先）
    
    private var timer: DispatchSourceTimer? //定时器
    //private var collectionTimer: Timer?

    private var teamJoinTimerA: Timer?  // 用于获取比赛剩余可加入时间的计时器
    private var teamJoinTimerB: Timer?  // 用于剩余可加入时间倒计时的计时器
    let teamJoinTimeWindow: Int = 180   // 组队模式下的可加入时间窗口
    
    // todo: 将频繁更新的属性移出competitionManager，否则会影响某些系统ui交互（如alert button）
    @Published var teamJoinRemainingTime: Int = 180         // 剩余可加入时间，频繁更新，暂时无交互受影响，先放在这里
    @Published var isTeamJoinWindowExpired: Bool = false    // 是否已过期

    // 计时器a和计时器b
    func startTeamJoinTimerA() {
        if teamJoinTimerA == nil {
            //print("start A")
            teamJoinTimerA = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                if !self.isTeam {
                    self.stopTeamJoinTimerA()
                    return
                }
                self.queryTeamExpiredDate()
                //print("A query...")
            }
        }
    }
    
    func stopTeamJoinTimerA() {
        teamJoinTimerA?.invalidate()
        teamJoinTimerA = nil
        //print("stop A")
    }
    
    func startTeamJoinTimerB() {
        if teamJoinTimerB == nil {
            //print("start B")
            teamJoinTimerB = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                
                if self.teamJoinRemainingTime > 0 {
                    self.teamJoinRemainingTime -= 1
                } else {
                    self.isTeamJoinWindowExpired = true
                    self.stopTeamJoinTimerB()
                }
            }
        }
    }
    
    func stopTeamJoinTimerB() {
        teamJoinTimerB?.invalidate()
        teamJoinTimerB = nil
        //print("stop B")
    }
    
    func stopAllTeamJoinTimers() {
        stopTeamJoinTimerA()
        stopTeamJoinTimerB()
    }
    
    func queryTeamExpiredDate() {
        guard let sport else { return }
        
        var recordID: String? = nil
        if sport == .Bike {
            recordID = currentBikeRecord?.record_id
        } else if sport == .Running {
            recordID = currentRunningRecord?.record_id
        }
        guard let record_id = recordID else { return }
        
        guard var components = URLComponents(string: "/competition/\(sport.rawValue)/query_team_expired_date") else { return }
        components.queryItems = [
            URLQueryItem(name: "record_id", value: record_id)
        ]
        guard let urlPath = components.string else { return }
            
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: TeamExpiredResponse.self) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        if let expired_date = unwrappedData.expired_date, let expired = DateParser.parseISO8601(expired_date) {
                            self.stopTeamJoinTimerA()
                            if self.teamJoinTimerB == nil {
                                let remainingTime = Int(expired.timeIntervalSinceNow)
                                if remainingTime > 0 {
                                    self.teamJoinRemainingTime = remainingTime
                                    self.startTeamJoinTimerB()
                                } else {
                                    self.isTeamJoinWindowExpired = true
                                    self.teamJoinRemainingTime = 0
                                }
                            }
                        }
                    }
                }
            default: break
            }
        }
    }

    private let dataHandleQueue = DispatchQueue(label: "com.sportsx.competition.imuHandleQueue", qos: .userInitiated)   // 串行队列，用于处理imu数据
    private let timerQueue = DispatchQueue(label: "com.sportsx.competition.timerQueue", qos: .userInitiated)            // 串行队列，用于处理手机端高频计时器的回调
    private let statsQueue = DispatchQueue(label: "com.sportsx.competition.statsHandleQueue")                           // 串行队列，用于处理外设收集的stats数据
    
    // Combine
    private var locationDetailViewCancellable: AnyCancellable?
    private var locationFreeTrainingCancellable: AnyCancellable?
    private var locationRouteTrainingCancellable: AnyCancellable?
    private var dataCancellables = Set<AnyCancellable>()


    private override init() {
        super.init()
        
        motionManager.accelerometerUpdateInterval = 0.05
        motionManager.gyroUpdateInterval = 0.05
        motionManager.magnetometerUpdateInterval = 0.05
        //requestMicrophoneAccess()
        setupDataBindings()
        // 嵌套的ObservableObject逐层订阅通知写在这里
    }
    
    // 设置 Combine 订阅
    func setupCompetitionLocationSubscription() {
        // 订阅位置更新
        locationDetailViewCancellable = LocationManager.shared.locationPublisher()
            .subscribe(on: DispatchQueue.global(qos: .background)) // 在后台处理订阅成功后的逻辑
            .receive(on: DispatchQueue.main) // 在主线程响应位置更新
            .sink { location in
                self.handleLocationUpdate(location)
            }
    }
    
    func deleteCompetitionLocationSubscription() {
        locationDetailViewCancellable?.cancel()
    }
    
    private func setupDataBindings() {
        // 监听比赛进行时dataWindow的每次数据更新
        dataFusionManager.predictionSubject
            .receive(on: dataHandleQueue)
            .sink { [weak self] snapshot in
                guard let self = self else { return }
                //Logger.competition.notice_public("predict time: \(snapshot.predictTime)")
                self.matchContext.sensorData = snapshot
                self.eventBus.emit(.matchIMUSensorUpdate, context: self.matchContext)
            }
            .store(in: &dataCancellables)
    }
    
    // 收到通知的回调（多检查点比赛：逐点 check/miss，对齐 route training）
    private func handleLocationUpdate(_ location: CLLocation) {
        // 当前比赛赛道的实时路线点（在主线程读入局部变量，再转后台处理）
        var routePoints: [RoutePointRealtime] = []
        if let rp = currentBikeRecord?.routePoints, sportFeature == .bikeRace {
            routePoints = rp
        } else if let rp = currentRunningRecord?.routePoints, sportFeature == .runningRace {
            routePoints = rp
        } else {
            return
        }

        userLocation = location
        DispatchQueue.global(qos: .background).async { [self] in
            if isRecording {
                guard let nextCPIndex = nextCheckPointIndex, nextCPIndex < routePoints.count else { return }

                // 终点（最后一个 checkpoint）安全区采集，用于 organizeEndTime 精确成绩
                if case .checkpoint(let endCp) = routePoints[routePoints.count - 1] {
                    let dis = location.distance(from: CLLocation(latitude: endCp.lat, longitude: endCp.lng))
                    if dis <= 2 * endCp.radius {
                        pathPointInEndSafetyRadius.append(PathPoint(
                            lat: location.coordinate.latitude,
                            lon: location.coordinate.longitude,
                            speed: location.speed,
                            altitude: location.altitude,
                            heart_rate: nil,
                            timestamp: location.timestamp.timeIntervalSince1970
                        ))
                    }
                }

                for index in nextCPIndex..<routePoints.count {
                    guard case .checkpoint(var checkpoint) = routePoints[index] else { return }
                    if checkpoint.isCheck || checkpoint.isMiss { continue }

                    let distance = location.distance(from: CLLocation(latitude: checkpoint.lat, longitude: checkpoint.lng))
                    // 中间检查点 3 米容错；终点用原始半径
                    let radius: Double = (index == routePoints.count - 1) ? checkpoint.radius : (checkpoint.radius + 3.0)

                    if distance <= radius {
                        // 到达终点 -> 结束比赛
                        if index == routePoints.count - 1 {
                            DispatchQueue.main.async {
                                self.stopCompetition()
                            }
                            return
                        }

                        checkpoint.isCheck = true
                        routePoints[index] = .checkpoint(checkpoint)

                        // 跳过的中间检查点标记 miss
                        if index > nextCPIndex {
                            for missIndex in nextCPIndex..<index {
                                guard case .checkpoint(var misspoint) = routePoints[missIndex] else { return }
                                if !misspoint.isCheck && !misspoint.isMiss {
                                    misspoint.isMiss = true
                                    routePoints[missIndex] = .checkpoint(misspoint)
                                }
                            }
                        }

                        DispatchQueue.main.async {
                            if self.sportFeature == .bikeRace {
                                self.currentBikeRecord?.routePoints = routePoints
                            } else if self.sportFeature == .runningRace {
                                self.currentRunningRecord?.routePoints = routePoints
                            }
                            self.nextCheckPointIndex = index + 1
                        }
                        break
                    }
                }
            } else {
                // 比赛开始前，检查用户是否在起点（routePoints[0]）检查区
                guard case .checkpoint(let cp) = routePoints.first else { return }
                let distance = location.distance(from: CLLocation(latitude: cp.lat, longitude: cp.lng))
                DispatchQueue.main.async {
                    self.isInValidArea = distance <= cp.radius
                }
            }
        }
    }
    
    func requestLocationAlwaysAuthorization() {
        let status = LocationManager.shared.authorizationStatus
        if status == .authorizedAlways {
            return
        } else {
            LocationManager.shared.requestAlwaysAuthorization()
        }
    }
    
    // Setup the audio recorder
    private func setupAudioRecorder() {
        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.m4a")
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder.prepareToRecord()
        } catch {
            Logger.competition.notice_public("Failed to setup audio recorder: \(error.localizedDescription)")
        }
    }
    
    // Helper function to get documents directory
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

    func startCompetition() {
        Logger.competition.notice_public("competition start")
        // 检查 Always Location 权限
        let status = LocationManager.shared.authorizationStatus
        if status != .authorizedAlways {
            alertTitle = "competition.realtime.start.popup.no_auth"
            alertMessage = "competition.realtime.start.popup.no_auth.content"
            showAlert = true
            return
        }
        
        // 检查 GPS 强度
        guard LocationManager.shared.signalStrength.bars > 1 else {
            let toast = Toast(message: "competition.realtime.start.toast.gps")
            ToastManager.shared.show(toast: toast)
            return
        }
        
        Task {
            guard await startCompetition_server() else { return }
            await MainActor.run {
                globalConfig.refreshRecordManageView = true
                startCompetitionSession()
            }
        }
    }
    
    func stopCompetition() {
        isRecording = false
        isShowWidget = false
        // Stop location updates
        deleteCompetitionLocationSubscription()
        LocationManager.shared.backToLastSet()
        //locationManager.stopUpdatingHeading()
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
        motionManager.stopMagnetometerUpdates()
        
        // Stop audio recording if applicable
        //stopRecordingAudio()
        
        // 停止手机和传感器设备的数据收集
        self.stopTimer()
        for (pos, dev) in deviceManager.deviceMap {
            if let device = dev, (sensorRequest & (1 << (pos.rawValue + 1))) != 0 {
                //stopCollecting(device: device)
                Logger.competition.notice_public("\(pos.name) watch stop collecting")
                device.stopCollection()
            }
        }
        
        eventBus.emit(.matchEnd, context: matchContext)
        
        finishCompetition_server()
        
#if DEBUG
        if SAVEPHONERAWDATA {
            self.finalizeCompetitionData()
        }
        if DUMPMATCHDATA {
            basePathData_debug = basePathData
            bikePathData_debug = bikePathData
            runningPathData_debug = runningPathData
        }
#endif
        resetCompetitionProperties()
        Logger.competition.notice_public("competition stop")
    }
    
    // 处理外设发送来的统计数据
    func handleStatsData(stats: [String: Any]) {
        statsQueue.async {
            var newData = self.realtimeStatisticData
            
            if let avgHeartRate = stats["avgHeartRate"] as? Double {
                self.matchContext.avgHeartRate = avgHeartRate
            }
            if let totalEnergy = stats["totalEnergy"] as? Double {
                self.matchContext.totalEnergy = totalEnergy
                newData.totalEnergy = Int(totalEnergy)
            }
            if let avgPower = stats["avgPower"] as? Double {
                self.matchContext.avgPower = avgPower
            }
            if let latestHeartRate = stats["latestHeartRate"] as? Double {
                self.matchContext.latestHeartRate = latestHeartRate
                newData.heartRate = Int(latestHeartRate)
            }
            if let latestPower = stats["latestPower"] as? Double {
                self.matchContext.latestPower = latestPower
                newData.power = Int(latestPower)
            }
            if let stepCadence = stats["stepCadence"] as? Double {
                //print("receive stepCadence: \(stepCadence)")
                self.matchContext.stepCadence = stepCadence
                newData.stepCadence = Int(stepCadence)
            }
            if let cycleCadence = stats["cycleCadence"] as? Double {
                self.matchContext.pedalCadence = cycleCadence
                newData.pedalCadence = Int(cycleCadence)
            }
            DispatchQueue.main.async {
                self.realtimeStatisticData = newData   // 一次性发布
            }
        }
    }
    
    // todo: 使用机器学习模型校验
    func verifyBikeMatchData() -> Double {
        guard startTime != nil else { return -1 }
        guard let startTime = basePathData.first?.timestamp,
              let endTime = basePathData.last?.timestamp,
              startTime < endTime else {
            return -1
        }
        
        guard !pathPointInEndSafetyRadius.isEmpty else { return -2 }
        
        guard basePathData.count >= 2 else {
            // 路径过短，不能校验，默认不合法
            return -1
        }
        
        // 总分数为100
        var score = 100.0
        
        let totalTime = endTime - startTime  // 秒
        let totalMeters = computeTotalDistance(path: basePathData)
        let avgSpeedKmh = (totalMeters / totalTime) * 3.6  // 转 km/h
        
        // 规则 1：平均速度太低或太高 → 不进行深度校验，直接视为合法或非法
        if avgSpeedKmh < 20 {
            return score
        }
        if avgSpeedKmh > 50 {
            return 0
        }
        
        // 规则 2：局部速度极端段
        var fastSpeedPoints = 0.0
        let segSpeeds = computeSegmentSpeeds(path: basePathData, windowMeters: 200)
        for v in segSpeeds {
            if v > 60 {
                fastSpeedPoints += 5
            } else if v > 50 {
                fastSpeedPoints += 2
            } else if v > 40 {
                fastSpeedPoints += 1
            }
        }
        if fastSpeedPoints >= 50 {
            score -= (fastSpeedPoints - 50) / 10
        }
        
        // 规则 3：海拔跳跃异常
        let altitudes = basePathData.map { $0.altitude }
        if detectElevationJump(elevs: altitudes, maxJump: 50.0) {
            score -= 10
        }
        
        // 规则 4：检测上坡路段的踏频是否与速度匹配
        var abnormalCounts = 0
        let pedalThreshold = 30.0
        let minSegmentLength = 3    // 避免太短的段误判
        let minAltitudeGain = -1.0  // >= -1.0m 算上坡
        let minSpeedDrop = 1.0      // 上坡期逐 pathpoint speed 至少下降 1 m/s
        var startIndex: Int? = nil
        
        // 找出 pedal_count <= 30 的连续段
        for i in 0..<bikePathData.count {
            let c: Double = bikePathData[i].pedal_cadence ?? bikePathData[i].estimate_pedal_count
            
            if c <= pedalThreshold {
                if startIndex == nil { startIndex = i }
                abnormalCounts += 1
            } else {
                if let s = startIndex, i - s >= minSegmentLength {
                    // 完成一个区段
                    processSegment(s..<i)
                }
                startIndex = nil
            }
        }
        
        // 末尾收尾
        if let s = startIndex, bikePathData.count - s >= minSegmentLength {
            processSegment(s..<bikePathData.count)
        }
        
        func processSegment(_ range: Range<Int>) {
            let segment = Array(bikePathData[range])
            
            // Step 2 — 判断是否明显上坡（总升高 > minAltitudeGain）
            let altStart = segment.first?.base.altitude ?? 0
            let altEnd = segment.last?.base.altitude ?? 0
            let altitudeGain = altEnd - altStart
            
            guard altitudeGain >= minAltitudeGain else { return }
            
            // Step 3 — 判断速度是否下降
            let startSpeed = segment.first?.base.speed ?? 0
            let endSpeed = segment.last?.base.speed ?? 0
            
            let speedDrop = startSpeed - endSpeed
            
            // 如果速度没有下降 → 可疑
            if speedDrop < minSpeedDrop {
                score -= (3 + minSpeedDrop - speedDrop)
            }
        }
        let cnt = max((abnormalCounts - bikePathData.count / 2), 0)
        score -= 10.0 * Double(cnt / bikePathData.count)
        
        // 规则 5：GPS 跳变数
        let jumpCount = countGpsJumps(path: basePathData, maxReasonableKmh: 60)
        score -= Double(jumpCount) * 5
        
        // 规则 6：功率 / 心率 一致性
        // 规则 7: 上坡时的速度 & 心率变化
        // 限制最低分数
        if score < 0 { score = 0 }
        return score
    }
    
    func verifyRunningMatchData() -> Double {
        guard startTime != nil else { return -1 }
        guard let startTime = basePathData.first?.timestamp,
              let endTime = basePathData.last?.timestamp,
              startTime < endTime else {
            return -1
        }
        
        // 未完成比赛
        guard !pathPointInEndSafetyRadius.isEmpty else { return -2 }
        
        guard basePathData.count >= 2 else {
            // 路径过短，不能校验，默认不合法
            return -1
        }
        
        // 总分数为100
        var score = 100.0
        
        let totalTime = endTime - startTime  // 秒
        let totalMeters = computeTotalDistance(path: basePathData)
        let avgSpeedKmh = (totalMeters / totalTime) * 3.6  // 转 km/h
        
        // 规则 1：平均速度太低或太高 → 不进行深度校验，直接视为合法或非法
        if avgSpeedKmh < 10 {
            return score
        }
        if avgSpeedKmh > 30 {
            return 0
        }
        
        // 规则 2：局部速度极端段
        var fastSpeedPoints = 0.0
        let segSpeeds = computeSegmentSpeeds(path: basePathData, windowMeters: 100)
        for v in segSpeeds {
            if v > 30 {
                fastSpeedPoints += 5
            } else if v > 25 {
                fastSpeedPoints += 2
            } else if v > 20 {
                fastSpeedPoints += 1
            }
        }
        if fastSpeedPoints >= 50 {
            score -= (fastSpeedPoints - 50) / 10
        }
        
        // 规则 3：海拔跳跃异常
        let altitudes = basePathData.map { $0.altitude }
        if detectElevationJump(elevs: altitudes, maxJump: 10.0) {
            score -= 5
        }
        
        // 规则 4：检测是否存在步数与速度不匹配的情况
        // 1). 连续 estimate_step_count == 0 的路段，如果在该连续段内位置发生明显移动 (>20m)，则视为异常段，每段减 5 分
        if !runningPathData.isEmpty {
            var zeroSegmentStartIndex: Int? = nil
            var penaltyCount = 0.0

            for i in 0..<runningPathData.count {
                let rpt = runningPathData[i]
                let step_cadence: Double = rpt.step_cadence ?? rpt.estimate_step_count
                if step_cadence == 0 {
                    if zeroSegmentStartIndex == nil {
                        zeroSegmentStartIndex = i
                    }
                } else {
                    // segment ended at i-1
                    if let start = zeroSegmentStartIndex {
                        // compute moved distance within [start, i-1]
                        var moved: Double = 0.0
                        if i - 1 > start {
                            for j in (start + 1)...(i - 1) {
                                moved += horizontalDistance(from: runningPathData[j-1].base, to: runningPathData[j].base)
                            }
                        } else {
                            // only one point in segment -> no movement
                            moved = 0.0
                        }
                        // 补上前 3s 的距离
                        if start > 0 {
                            moved += horizontalDistance(from: runningPathData[start-1].base, to: runningPathData[start].base)
                        }
                        if moved > 20.0 {
                            penaltyCount += 1.0
                        }
                        zeroSegmentStartIndex = nil
                    }
                }
            }
            // handle tail segment if ended with zeros
            if let start = zeroSegmentStartIndex {
                var moved: Double = 0.0
                if runningPathData.count - 1 > start {
                    for j in (start + 1)...(runningPathData.count - 1) {
                        moved += horizontalDistance(from: runningPathData[j-1].base, to: runningPathData[j].base)
                    }
                }
                // 补上前 3s 的距离
                if start > 0 {
                    moved += horizontalDistance(from: runningPathData[start-1].base, to: runningPathData[start].base)
                }
                if moved > 20.0 {
                    penaltyCount += 1.0
                }
            }

            // apply penalty: 每个异常段 -5 分
            if penaltyCount > 0 {
                score -= 5.0 * penaltyCount
            }
        }

        // 2). 每 10 个轨迹点为一个区间（非重叠），计算区间内总距离 / 总步数 = 步长 l（单位：m）
        //    若 l > 2m 则视为不合理，按 (l - 2) / 2 分扣分（注：可累加）
        let windowSize = 10
        if runningPathData.count >= windowSize {
            var idx = 0
            while idx + windowSize <= runningPathData.count {
                let window = Array(runningPathData[idx..<idx + windowSize])
                // total distance in window
                var totalDist: Double = 0.0
                for k in 1..<window.count {
                    totalDist += horizontalDistance(from: window[k-1].base, to: window[k].base)
                }
                // total estimated steps in this window (sum of estimate_step_count)
                let totalSteps = window.reduce(0.0) {
                    $0 + ($1.step_cadence ?? $1.estimate_step_count)
                }
                if totalSteps > 0.0 {
                    let stepLength = totalDist / totalSteps // meters per step
                    if stepLength > 2.0 {
                        let penalty = (stepLength - 2.0) / 2.0
                        score -= penalty
                    }
                } else {
                    // 若 totalSteps == 0 且有明显移动（例如 > 8m）可适当扣分（防止零步计但有移动）
                    if totalDist > 10.0 {
                        // 这里扣较小分，以免过度惩罚
                        score -= 1.0
                    }
                }
                idx += windowSize
            }
        }
        
        // 规则 5：GPS 跳变数
        let jumpCount = countGpsJumps(path: basePathData, maxReasonableKmh: 30)
        score -= Double(jumpCount) * 5
        
        // 规则 6：功率 / 心率 一致性
        // 规则 7: 上坡时的速度 & 心率变化
        // 限制最低分数
        if score < 0 { score = 0 }
        
        return score
    }
    
    // 整理轨迹和计算最终成绩
    func organizeEndTime() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard !pathPointInEndSafetyRadius.isEmpty else {
            return formatter.string(from: Date())
        }

        // 终点 = 当前赛道最后一个 checkpoint
        let endRoutePoints: [RoutePointRealtime]? = (sportFeature == .bikeRace) ? currentBikeRecord?.routePoints
            : (sportFeature == .runningRace) ? currentRunningRecord?.routePoints : nil
        guard let lastPoint = endRoutePoints?.last, case .checkpoint(let endCp) = lastPoint else {
            return formatter.string(from: Date())
        }
        let endCoordinate = CLLocationCoordinate2D(latitude: endCp.lat, longitude: endCp.lng)
        let endRadius = endCp.radius

        // Step 1: 第一个在终点内的点
        for p in pathPointInEndSafetyRadius {
            let distance = CLLocation(latitude: p.lat, longitude: p.lon)
                .distance(from: CLLocation(latitude: endCoordinate.latitude, longitude: endCoordinate.longitude))
            if distance <= endRadius {
                return formatter.string(from: Date(timeIntervalSince1970: p.timestamp))
            }
        }

        // Step 2: 检查线段是否穿过终点圆
        for i in 1..<pathPointInEndSafetyRadius.count {
            let p1 = pathPointInEndSafetyRadius[i-1]
            let p2 = pathPointInEndSafetyRadius[i]
            if let t = intersectionRatioBetweenSegment(p1, p2, circleCenter: endCoordinate, radius: endRadius) {
                let crossTimestamp = p1.timestamp + (p2.timestamp - p1.timestamp) * t
                return formatter.string(from: Date(timeIntervalSince1970: crossTimestamp))
            }
        }

        // Step 3: 最后一个点外推
        if let last = pathPointInEndSafetyRadius.last {
            let distance = CLLocation(latitude: last.lat, longitude: last.lon)
                .distance(from: CLLocation(latitude: endCoordinate.latitude, longitude: endCoordinate.longitude))
            if last.speed > 0.5 {
                let deltaTime = distance / last.speed
                let adjustedTime = last.timestamp + deltaTime
                return formatter.string(from: Date(timeIntervalSince1970: adjustedTime))
            } else {
                return formatter.string(from: Date(timeIntervalSince1970: last.timestamp))
            }
        }
        
        // fallback
        return formatter.string(from: Date())
    }
    
    // 判断线段 (p1, p2) 是否与以 circleCenter, radius 的圆相交，
    // 如果相交则返回交点在 p1→p2 上的比例 t（0~1），否则返回 nil
    private func intersectionRatioBetweenSegment(
        _ p1: PathPoint, _ p2: PathPoint,
        circleCenter: CLLocationCoordinate2D, radius: Double
    ) -> Double? {
        let x1 = p1.lon, y1 = p1.lat
        let x2 = p2.lon, y2 = p2.lat
        let cx = circleCenter.longitude, cy = circleCenter.latitude
        
        // 将经纬度近似为局部平面坐标（误差可忽略）
        let dx = x2 - x1
        let dy = y2 - y1
        let fx = x1 - cx
        let fy = y1 - cy
        
        let a = dx*dx + dy*dy
        let b = 2 * (fx*dx + fy*dy)
        let c = fx*fx + fy*fy - radius*radius
        
        let discriminant = b*b - 4*a*c
        if discriminant < 0 { return nil } // 没有交点
        
        let sqrtDisc = sqrt(discriminant)
        let t1 = (-b - sqrtDisc) / (2*a)
        let t2 = (-b + sqrtDisc) / (2*a)
        
        // 取第一个合法交点（0~1）
        if (0...1).contains(t1) {
            return t1
        } else if (0...1).contains(t2) {
            return t2
        } else {
            return nil
        }
    }
    
    // MARK: - 待上传数据本地缓存（上传失败时落盘，供用户在记录页手动重传）

    // 运动时长（基于轨迹首尾时间戳，仅用于待上传记录的展示）
    private var workoutDuration: TimeInterval {
        guard let first = basePathData.first?.timestamp,
              let last = basePathData.last?.timestamp else { return 0 }
        return max(last - first, 0)
    }

    // 写前落盘：发起 finish 请求前保存完整请求数据，确保即使请求中途 App 被杀数据仍在
    private func savePendingUpload(id: String, category: PendingUploadCategory, mode: PendingUploadMode, endpointPath: String, body: Data, title: String?) {
        guard let sport else { return }
        let upload = PendingWorkoutUpload(
            id: id,
            userID: userManager.user.userID,
            sport: sport,
            category: category,
            mode: mode,
            endpointPath: endpointPath,
            body: body,
            createdAt: Date(),
            distanceMeters: computeTotalDistance(path: basePathData),
            duration: workoutDuration,
            title: title
        )
        PendingUploadManager.shared.save(upload)
    }

    // 上传成功后移除本地缓存
    private func removePendingUpload(id: String) {
        PendingUploadManager.shared.remove(id: id, userID: userManager.user.userID)
    }

    // 上传失败时提示用户数据已保存、可稍后手动上传
    private func notifyPendingUploadSaved() {
        DispatchQueue.main.async {
            PopupWindowManager.shared.presentPopup(
                message: "upload.pending.saved_toast",
                bottomButtons: [.confirm()]
            )
        }
    }

    // todo: 暂时开始时间和结束时间都由客户端决定，未来可在服务端接收到请求后记录时间进行二次验证
    func finishCompetition_server() {
        let optimizeEndTime = organizeEndTime()
        //print("optimizeEndTime: \(optimizeEndTime)")
        if let record = currentBikeRecord, sportFeature == .bikeRace {
            var validationResult = verifyBikeMatchData()
#if DEBUG
            if DUMPMATCHDATA {
                validationScore_debug = validationResult
            }
            if SKIPVARIFYSCOREUPLOAD {
                validationResult = 100.0
            }
#endif
            //print("BikeMatchData verify result: \(validationResult)")
            var headers: [String: String] = [:]
            headers["Content-Type"] = "application/json"
            let uploadID = UUID().uuidString
            let requestData = BikeFinishMatchRequest(
                validation_score: validationResult,
                record_id: record.record_id,
                end_time: optimizeEndTime,
                bonus_in_cards: matchContext.bonusEachCards,
                team_bonus: matchContext.teamBonus,
                path: bikePathData,
                client_upload_id: uploadID
            )
            guard let encodedBody = try? JSONEncoder().encode(requestData) else {
                return
            }
            let endpointPath = "/competition/bike/finish_\(record.isTeam ? "team" : "single")_competition"
            // 写前落盘
            savePendingUpload(id: uploadID, category: .race, mode: record.isTeam ? .raceTeam : .raceSingle, endpointPath: endpointPath, body: encodedBody, title: record.trackName)

            let request = APIRequest(path: endpointPath, method: .post, headers: headers, body: encodedBody, requiresAuth: true)
            NetworkService.sendRequest(with: request, decodingType: MatchFinishResponse.self, showLoadingToast: true, showErrorToast: true) { result in
                switch result {
                case .success(let data):
                    self.removePendingUpload(id: uploadID)
                    guard let unwrappedData = data else { return }
                    self.globalConfig.refreshRecordManageView = true
                    self.globalConfig.refreshTeamManageView = true
                    DispatchQueue.main.async {
                        if let matchResult = unwrappedData.match_result {
                            for asset in matchResult.rewards {
                                self.assetManager.updateCCAsset(type: asset.ccasset_type, newBalance: asset.new_ccamount)
                            }
                            PopupWindowManager.shared.presentPopup(
                                title: "competition.record.complete",
                                bottomButtons: [
                                    .confirm()
                                ]
                            ) {
                                VStack {
                                    if matchResult.is_track_best {
                                        Text("competition.record.result.track_best")
                                    } else if matchResult.is_user_best {
                                        Text("competition.record.result.person_best")
                                    } else {
                                        Text("competition.record.result.normal")
                                    }
                                    XPProgressView(beforeXP: matchResult.xp_before, deltaXP: matchResult.xp_delta)
                                    HStack(spacing: 10) {
                                        ForEach(matchResult.rewards) { reward in
                                            HStack(spacing: 4) {
                                                Image(reward.ccasset_type.iconName)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 20)
                                                Text("+ \(reward.reward_amount)")
                                                    .font(.system(size: 15))
                                                    .fontWeight(.semibold)
                                            }
                                        }
                                    }
                                }
                                .foregroundStyle(Color.white)
                            }
                        }
                        self.navigationManager.append(.bikeRaceRecordDetailView(recordID: record.record_id))
                        self.dailyTaskManager.queryDailyTask(sport: self.userManager.user.defaultSport)
                    }
                case .failure(let error):
                    switch error {
                    case .businessError:
                        self.removePendingUpload(id: uploadID)
                    default:
                        self.notifyPendingUploadSaved()
                    }
                    DispatchQueue.main.async {
                        var cardSelectViewIndex = 0
                        var realtimeViewIndex = 0
                        if let index = self.navigationManager.path.firstIndex(where: { $0.string == "competitionCardSelectView" }) {
                            cardSelectViewIndex = self.navigationManager.path.count - index
                        }
                        if let index = self.navigationManager.path.firstIndex(where: { $0.string == "competitionRealtimeView" }) {
                            realtimeViewIndex = self.navigationManager.path.count - index
                        }
                        let lastToRemove = max(cardSelectViewIndex, realtimeViewIndex)
                        self.navigationManager.removeLast(lastToRemove)
                    }
                }
            }
        }
        if let record = currentRunningRecord, sportFeature == .runningRace {
            var validationResult = verifyRunningMatchData()
#if DEBUG
            if DUMPMATCHDATA {
                validationScore_debug = validationResult
            }
            if SKIPVARIFYSCOREUPLOAD {
                validationResult = 100.0
            }
#endif
            //print("RunningMatchData verify result: \(validationResult)")
            var headers: [String: String] = [:]
            headers["Content-Type"] = "application/json"
            let uploadID = UUID().uuidString
            let requestData = RunningFinishMatchRequest(
                validation_score: validationResult,
                record_id: record.record_id,
                end_time: optimizeEndTime,
                bonus_in_cards: matchContext.bonusEachCards,
                team_bonus: matchContext.teamBonus,
                path: runningPathData,
                client_upload_id: uploadID
            )
            guard let encodedBody = try? JSONEncoder().encode(requestData) else {
                return
            }
            let endpointPath = "/competition/running/finish_\(record.isTeam ? "team" : "single")_competition"
            // 写前落盘
            savePendingUpload(id: uploadID, category: .race, mode: record.isTeam ? .raceTeam : .raceSingle, endpointPath: endpointPath, body: encodedBody, title: record.trackName)

            let request = APIRequest(path: endpointPath, method: .post, headers: headers, body: encodedBody, requiresAuth: true)
            NetworkService.sendRequest(with: request, decodingType: MatchFinishResponse.self, showLoadingToast: true, showErrorToast: true) { result in
                switch result {
                case .success(let data):
                    self.removePendingUpload(id: uploadID)
                    guard let unwrappedData = data else { return }
                    self.globalConfig.refreshRecordManageView = true
                    self.globalConfig.refreshTeamManageView = true
                    DispatchQueue.main.async {
                        if let matchResult = unwrappedData.match_result {
                            for asset in matchResult.rewards {
                                self.assetManager.updateCCAsset(type: asset.ccasset_type, newBalance: asset.new_ccamount)
                            }
                            PopupWindowManager.shared.presentPopup(
                                title: "competition.record.complete",
                                bottomButtons: [
                                    .confirm()
                                ]
                            ) {
                                VStack {
                                    if matchResult.is_track_best {
                                        Text("competition.record.result.track_best")
                                    } else if matchResult.is_user_best {
                                        Text("competition.record.result.person_best")
                                    } else {
                                        Text("competition.record.result.normal")
                                    }
                                    XPProgressView(beforeXP: matchResult.xp_before, deltaXP: matchResult.xp_delta)
                                    HStack(spacing: 10) {
                                        ForEach(matchResult.rewards) { reward in
                                            HStack(spacing: 4) {
                                                Image(reward.ccasset_type.iconName)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 20)
                                                Text("+ \(reward.reward_amount)")
                                                    .font(.system(size: 15))
                                                    .fontWeight(.semibold)
                                            }
                                        }
                                    }
                                }
                                .foregroundStyle(Color.white)
                            }
                        }
                        self.navigationManager.append(.runningRaceRecordDetailView(recordID: record.record_id))
                        self.dailyTaskManager.queryDailyTask(sport: self.userManager.user.defaultSport)
                    }
                case .failure(let error):
                    switch error {
                    case .businessError:
                        self.removePendingUpload(id: uploadID)
                    default:
                        self.notifyPendingUploadSaved()
                    }
                    DispatchQueue.main.async {
                        var cardSelectViewIndex = 0
                        var realtimeViewIndex = 0
                        if let index = self.navigationManager.path.firstIndex(where: { $0.string == "competitionCardSelectView" }) {
                            cardSelectViewIndex = self.navigationManager.path.count - index
                        }
                        if let index = self.navigationManager.path.firstIndex(where: { $0.string == "competitionRealtimeView" }) {
                            realtimeViewIndex = self.navigationManager.path.count - index
                        }
                        let lastToRemove = max(cardSelectViewIndex, realtimeViewIndex)
                        self.navigationManager.removeLast(lastToRemove)
                    }
                }
            }
        }
    }
    
    func startCompetition_server() async -> Bool {
        startTime = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let record = currentBikeRecord, sport == .Bike {
            var headers: [String: String] = [:]
            headers["Content-Type"] = "application/json"
            
            var body: [String: String] = [:]
            body["record_id"] = record.record_id
            if let start = startTime {
                body["start_time"] = formatter.string(from: start)
            }
            guard let encodedBody = try? JSONEncoder().encode(body) else {
                return false
            }
            let request = APIRequest(path: "/competition/bike/start_\(record.isTeam ? "team" : "single")_competition", method: .post, headers: headers, body: encodedBody, requiresAuth: true)
            let result = await NetworkService.sendAsyncRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showErrorToast: true)
            switch result {
            case .success:
                return true
            case .failure:
                return false
            }
        }
        if let record = currentRunningRecord, sport == .Running {
            var headers: [String: String] = [:]
            headers["Content-Type"] = "application/json"
            
            var body: [String: String] = [:]
            body["record_id"] = record.record_id
            if let start = startTime {
                body["start_time"] = formatter.string(from: start)
            }
            guard let encodedBody = try? JSONEncoder().encode(body) else {
                return false
            }
            let request = APIRequest(path: "/competition/running/start_\(record.isTeam ? "team" : "single")_competition", method: .post, headers: headers, body: encodedBody, requiresAuth: true)
            let result = await NetworkService.sendAsyncRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showErrorToast: true)
            switch result {
            case .success:
                return true
            case .failure:
                return false
            }
        }
        await MainActor.run() {
            ToastManager.shared.show(toast: Toast(message: "competition.realtime.start.toast.sport_not_support"))
        }
        return false
    }
    
    // 组队比赛开始时使用队伍奖励卡牌的逻辑
    func startCompetitionWithTeamBonusCard(cardID: String) {
        guard isTeam, let sport else { return }
        guard var components = URLComponents(string: "/competition/\(sport.rawValue)/start_competition_with_team_bonus_card") else { return }
        if let record = currentBikeRecord, sport == .Bike {
            components.queryItems = [
                URLQueryItem(name: "record_id", value: record.record_id),
                URLQueryItem(name: "card_id", value: cardID)
            ]
        }
        if let record = currentRunningRecord, sport == .Running {
            components.queryItems = [
                URLQueryItem(name: "record_id", value: record.record_id),
                URLQueryItem(name: "card_id", value: cardID)
            ]
        }
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showErrorToast: true) { _ in }
    }
    
    func startCompetitionSession() {
        guard let sport, sportFeature?.featureType == .race else { return }
        fetchPaceBaseline()
        // 清理定时器任务可能残留的数据
        realtimeStatisticData = .empty
        basePathData = []
        bikePathData = []
        runningPathData = []
        dataFusionManager.elapsedTime = 0
        
        // 默认将所有加载卡牌添加进 matchContext 中
        //for card in activeCardEffects {
        //    matchContext.addOrUpdateBonus(cardID: card.cardID, bonus: 0)
        //}
        eventBus.emit(.matchStart, context: matchContext)
        
        // 重置组队模式下的计时环境
        stopAllTeamJoinTimers()
        teamJoinRemainingTime = teamJoinTimeWindow
        isTeamJoinWindowExpired = false
        
        // 标记起点已 check，下一个待经过检查点为 1（对齐 route training）
        if sportFeature == .bikeRace, var rp = currentBikeRecord?.routePoints, !rp.isEmpty,
           case .checkpoint(var sp) = rp[0] {
            sp.isCheck = true
            rp[0] = .checkpoint(sp)
            currentBikeRecord?.routePoints = rp
        } else if sportFeature == .runningRace, var rp = currentRunningRecord?.routePoints, !rp.isEmpty,
                  case .checkpoint(var sp) = rp[0] {
            sp.isCheck = true
            rp[0] = .checkpoint(sp)
            currentRunningRecord?.routePoints = rp
        }
        nextCheckPointIndex = 1

        isRecording = true

#if DEBUG
        if SAVEPHONERAWDATA {
            competitionData = []
        }
#endif
        
        // Start location updates
        LocationManager.shared.changeToHighUpdate()

        // Start accelerometer/gyro/magnet updates
        motionManager.startAccelerometerUpdates()
        motionManager.startGyroUpdates()
        motionManager.startMagnetometerUpdates()
        
        // 使用定时器每0.05秒记录一次数据
        self.startCompetitionTimer()
        let isNeedPhoneData = sensorRequest & 0b000001 != 0
        let sensorRequest = sensorRequest >> 1
        
        // 所有设备开始收集数据
        if isNeedPhoneData {
            dataFusionManager.deviceNeedToWork |= 0b000001
        }
        for (pos, dev) in deviceManager.deviceMap {
            if let device = dev, (sensorRequest & (1 << pos.rawValue)) != 0 {
                // 当前 dataFusionManager.deviceNeedToWork 和 device.enableIMU 信息交给 each cards 配置
                //dataFusionManager.deviceNeedToWork |= (1 << (pos.rawValue + 1))
                //startCollecting(device: device)
                Logger.competition.notice_public("\(pos.name) watch data start collecting")
                device.startCollection(activityType: sport, locationType: "outdoor")  // 开始数据收集
            }
        }
    }
    
    // 启动定时器
    // todo: 使用定时 Task 代替 GCD 定时器，彻底解决残留定时任务与清理任务的竞态问题
    private func startCompetitionTimer() {
        // 在比赛开始时已记录下 startTime = Date()
        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now(), repeating: 0.05) // 每0.05秒触发一次
        var tickCounter = 0 // 用于计数，每次事件触发加1
        
        timer.setEventHandler { [weak self] in
            guard let self = self, self.isRecording, let start = self.startTime else { return }
            
            // 记录 phone 端数据
            if self.sensorRequest & 0b000001 != 0 && self.isRecording {
                self.recordMotionData()
            }
            
            // 更新计数器
            tickCounter += 1
            
            // 每 1 秒更新 elapsedTime
            if tickCounter % 20 == 0 { // 20 * 0.05s = 1s
                let newElapsedTime = Date().timeIntervalSince(start)
                DispatchQueue.main.async {
                    // 再次检查比赛状态，避免比赛结束时计时器闭包延迟更新重置elapsedTime
                    if self.isRecording {
                        self.dataFusionManager.elapsedTime = newElapsedTime
                    }
                }
            }
            
            // 每3秒记录一次 path 数据 & 发出 matchCycleUpdate 信号
            if tickCounter % 60 == 0 && self.isRecording {
                // 当前支持的最大比赛时间为 2h
                if self.dataFusionManager.elapsedTime > 7200 {
                    DispatchQueue.main.async {
                        self.stopCompetition()
                    }
                }
                DispatchQueue.main.async {
                    self.recordPath()
                }
                eventBus.emit(.matchCycleUpdate, context: matchContext)
                tickCounter = 0 // 重置计数器
            }
        }
        self.timer = timer
        timer.resume()
        Logger.competition.notice_public("start phone timer.")
    }
    
    // 停止定时器
    private func stopTimer() {
        timer?.cancel()
        timer = nil
        recordPath()
        Logger.competition.notice_public("stop phone timer.")
    }
    
    // 记录path数据
    private func recordPath() {
        guard let location = LocationManager.shared.getLocation() else {
            //print("location data missed in path point.")
            return
        }
        let basePoint = PathPoint(
            lat: location.coordinate.latitude,
            lon: location.coordinate.longitude,
            speed: location.speed,
            altitude: location.altitude,
            heart_rate: matchContext.latestHeartRate,
            timestamp: Date().timeIntervalSince1970
        )
        if let lastPoint = basePathData.last {
            let distance = horizontalDistance(from: lastPoint, to: basePoint)
            
            self.horizontalDistanceWindow += distance
            let allowElevationUpdate = horizontalDistanceWindow >= 5
            if allowElevationUpdate {
                horizontalDistanceWindow = max(0, horizontalDistanceWindow - 5)
            }
            var elevGain = 0.0
            if allowElevationUpdate {
                let smoothedAlt = smoothedAltitude(from: location.altitude)
                elevGain = smoothedAlt - matchContext.altitude
                matchContext.altitude = smoothedAlt
                pendingElevationGain = max(pendingElevationGain + elevGain, 0)
            }
            
            matchContext.speed = 3.6 * distance / 3.0
            matchContext.distance += distance
            DispatchQueue.main.async {
                self.realtimeStatisticData.distance += distance
                self.realtimeStatisticData.avgSpeed = 3.6 * self.realtimeStatisticData.distance / self.dataFusionManager.elapsedTime
                if allowElevationUpdate, self.pendingElevationGain > self.elevationThreshold {
                    self.realtimeStatisticData.elevationGain += self.pendingElevationGain
                    self.pendingElevationGain = 0
                }
            }
        }
        basePathData.append(basePoint)
        updatePaceEstimate(coord: location.coordinate)
        if currentBikeRecord != nil, sport == .Bike {
            let pathPoint = BikePathPoint(
                base: basePoint,
                power: matchContext.latestPower,
                pedal_cadence: matchContext.pedalCadence,
                estimate_pedal_count: matchContext.estimatePedal,
                card_bonus: matchContext.bonusEachCards
            )
            bikePathData.append(pathPoint)
        }
        if currentRunningRecord != nil, sport == .Running {
            let pathPoint = RunningPathPoint(
                base: basePoint,
                power: matchContext.latestPower,
                step_cadence: matchContext.stepCadence,
                vertical_amplitude: nil,
                touchdown_time: nil,
                step_size: nil,
                estimate_step_count: matchContext.estimateStep,
                card_bonus: matchContext.bonusEachCards
            )
            runningPathData.append(pathPoint)
        }
        //print(pathPoint)
    }
    
    // 记录运动数据
    private func recordMotionData() {
        // 获取当前数据
        //guard let location = LocationManager.shared.getLocation() else {
        //    print("No location data available.")
        //    return
        //}
        
        let altitude = LocationManager.shared.getLocation()?.altitude ?? -11034
        let speed = LocationManager.shared.getLocation()?.speed ?? -1
        
        let acceleration = motionManager.accelerometerData?.acceleration ?? CMAcceleration(x: 0, y: 0, z: 0)
        let gyro = motionManager.gyroData?.rotationRate ?? CMRotationRate(x: 0, y: 0, z: 0)
        let magneticField = motionManager.magnetometerData?.magneticField ?? CMMagneticField(x: 0, y: 0, z: 0)
        let audioSample: Bool = false // 根据需要处理音频数据
        //let zone = NSTimeZone.system
        //let timeInterval = zone.secondsFromGMT()
        //let dateNow = Date().addingTimeInterval(TimeInterval(timeInterval))
        
        let dataPoint = PhoneData(
            timestamp: Date().timeIntervalSince1970,
            altitude: altitude,
            speed: speed,
            accX: acceleration.x,
            accY: acceleration.y,
            accZ: acceleration.z,
            gyroX: gyro.x,
            gyroY: gyro.y,
            gyroZ: gyro.z,
            magX: magneticField.x,
            magY: magneticField.y,
            magZ: magneticField.z,
            audioSample: audioSample
        )
        
        // 暂时默认都使用dataFusionManager管理phone data
        self.dataFusionManager.addPhoneData(dataPoint)
        
#if DEBUG
        if SAVEPHONERAWDATA {
            competitionData.append(dataPoint)
            // 检查是否达到批量保存条件
            if competitionData.count >= batchSize {
                let batch = competitionData
                competitionData.removeAll()
                saveBatchAsCSV(dataBatch: batch)
            }
        }
#endif
    }
    
    private func startRecordingAudio() {
        // Optional: Setup audio recording if needed
    }
    
    private func stopRecordingAudio() {
        // Optional: Stop audio recording and save the sample
    }
    
    // 设置运动和记录，准备开始比赛
    func resetBikeRaceRecord(record: BikeRaceRecord) {
        sportFeature = .bikeRace
        currentBikeRecord = record
        nextCheckPointIndex = nil
        isInValidArea = false
    }

    func resetRunningRaceRecord(record: RunningRaceRecord) {
        sportFeature = .runningRace
        currentRunningRecord = record
        nextCheckPointIndex = nil
        isInValidArea = false
    }
    
    func loadMatchEnv() {
        guard selectedCards.count <= 4 else {
            ToastManager.shared.show(toast: Toast(message: "competition.magiccard.error.count"))
            return
        }
        
        // 卸载所有effects
        // todo: 未来考虑是否将清理操作分散到 every card effect 里的 unload() 中
        sensorRequest = 0
        dataFusionManager.resetAll()
        deviceManager.resetAllDeviceStatus()
        
        matchContext.reset()
        matchContext.isTeam = isTeam
        matchContext.sportFeature = sportFeature
        
        var effects: [MagicCardEffect] = []
        do {
            for card in selectedCards {
                let effect = try MagicCardFactory.createEffect(
                    level: card.level,
                    from: card.cardDef
                )
                effects.append(effect)
            }
            activeCardEffects = effects
        } catch {
            ToastManager.shared.show(toast: Toast(message: error.localizedDescription))
            return
        }
        
        for effect in activeCardEffects {
            matchContext.addOrUpdateBonus(cardID: effect.cardID, bonus: 0)
        }
        
        if sportFeature == .runningRace {
            activeCardEffects.append(RunningValidationEffect())
        } else if sportFeature == .bikeRace {
            activeCardEffects.append(BikeValidationEffect())
        }
        eventBus.reset()
        Task {
            await MainActor.run {
                ToastManager.shared.start(toast: LoadingToast())
            }
            for effect in activeCardEffects {
                effect.register(eventBus: eventBus)
                let prepared = await effect.load()
                if !prepared {
                    await MainActor.run {
                        ToastManager.shared.show(toast: Toast(message: "competition.realtime.start.toast.card_loading_failed"))
                        ToastManager.shared.finish()
                    }
                    return
                }
            }
            // 支持脱离卡牌单独使用传感器设备辅助记录比赛数据
            addDefaultDevice()
            await MainActor.run {
                switch sportFeature?.featureType {
                case .race:
                    self.navigationManager.append(.competitionRealtimeView)
                case .routeTraining:
                    self.navigationManager.append(.routeTrainingRealtimeView)
                default: return
                }
                ToastManager.shared.finish()
            }
        }
    }
    
    func addDefaultDevice() {
        let sensorReq = sensorRequest >> 1
        guard sensorReq == 0, let defaultPos = deviceManager.defaultSensorPos else { return }
        sensorRequest |= (1 << (defaultPos.rawValue + 1))
    }
    
    // 开赛时拉取配速基线（有序完赛成绩 + 自己 PB 的 split profile），构建实时估算器
    func fetchPaceBaseline() {
        paceEstimator = nil
        lastPaceUpdate = .distantPast
        DispatchQueue.main.async {
            self.pacePredictedRank = nil
            self.pacePredictedTotal = 0
            self.paceHasPB = false
            self.paceDeltaTime = nil
            self.paceDeltaDistance = nil
        }

        var urlPath: String? = nil
        var routePoints: [RoutePointRealtime] = []
        switch sportFeature {
        case .bikeRace:
            guard let record = currentBikeRecord else { return }
            routePoints = record.routePoints
            urlPath = "/competition/bike/track_pace_baseline?record_id=\(record.record_id)"
        case .runningRace:
            guard let record = currentRunningRecord else { return }
            routePoints = record.routePoints
            urlPath = "/competition/running/track_pace_baseline?record_id=\(record.record_id)"
        case .bikeRouteTraining:
            guard let route = currentBikeRoute else { return }
            routePoints = route.routePoints
            urlPath = "/training/bike/route_pace_baseline?route_id=\(route.routeID)"
        case .runningRouteTraining:
            guard let route = currentRunningRoute else { return }
            routePoints = route.routePoints
            urlPath = "/training/running/route_pace_baseline?route_id=\(route.routeID)"
        default:
            return
        }
        guard let path = urlPath else { return }
        let points = routePoints
        let request = APIRequest(path: path, method: .get, requiresAuth: true)
        NetworkService.sendRequest(with: request, decodingType: PaceBaselineResponse.self) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let data):
                guard let data else { return }
                let estimator = RoutePaceEstimator(routePoints: points, finishTimes: data.finish_times, pbProfile: data.pb_profile)
                self.paceEstimator = estimator
                DispatchQueue.main.async {
                    self.paceHasPB = estimator?.hasPB ?? false
                }
            case .failure:
                break   // 静默失败：仅不展示实时配速，不打扰运动
            }
        }
    }

    // 运动中按定位更新实时预测名次与自我对比（节流 ~1s）
    func updatePaceEstimate(coord: CLLocationCoordinate2D) {
        guard isRecording, let estimator = paceEstimator else { return }
        let now = Date()
        guard now.timeIntervalSince(lastPaceUpdate) >= 1.0 else { return }
        lastPaceUpdate = now

        let d = estimator.project(coord)
        let elapsed = dataFusionManager.elapsedTime
        // 有效用时估计：原始用时 - 已累计的卡牌奖励时间（v1 暂忽略熟悉度/训练状态/罚时，仅预测用途）
        let cardBonus = matchContext.bonusEachCards.reduce(0.0) { $0 + $1.bonus_time }
        let tEff = max(0, elapsed - cardBonus)

        let rankResult = estimator.projectedRank(effectiveTime: tEff, currentDistance: d)
        var deltaT: Double? = nil
        var deltaD: Double? = nil
        if estimator.hasPB {
            if let pbT = estimator.pbTime(atDistance: d) { deltaT = pbT - tEff }
            if let pbD = estimator.pbDistance(atTime: tEff) { deltaD = d - pbD }
        }
        DispatchQueue.main.async {
            if let r = rankResult {
                self.pacePredictedRank = r.rank
                self.pacePredictedTotal = r.total
            }
            self.paceDeltaTime = deltaT
            self.paceDeltaDistance = deltaD
        }
    }

    func resetCompetitionProperties() {
        dataFusionManager.resetAll()
        paceEstimator = nil
        lastPaceUpdate = .distantPast
        pacePredictedRank = nil
        pacePredictedTotal = 0
        paceHasPB = false
        paceDeltaTime = nil
        paceDeltaDistance = nil
        
        teamJoinRemainingTime = teamJoinTimeWindow
        isTeamJoinWindowExpired = false
        currentBikeRecord = nil
        currentRunningRecord = nil
        currentBikeRoute = nil
        currentRunningRoute = nil
        selectedCards.removeAll()
        activeCardEffects.removeAll()
        eventBus.reset()
        matchContext.reset()
        realtimeStatisticData = .empty
        sensorRequest = 0
        startTime = nil
        sportFeature = nil
        userLocation = nil
        
        basePathData = []
        bikePathData = []
        runningPathData = []
        bikeFreeTrainingPathData = []
        runningFreeTrainingPathData = []
        bikeRouteTrainingPathData = []
        runningRouteTrainingPathData = []
        
        nextCheckPointIndex = nil
        
        isInValidArea = false
        pathPointInEndSafetyRadius = []
        recentAltitudeSamples = []
        horizontalDistanceWindow = 0.0
        pendingElevationGain = 0.0
    }
}

// 自由训练功能
extension CompetitionManager {
    func setupFreeTrainingLocationSubscription() {
        locationFreeTrainingCancellable = LocationManager.shared.locationPublisher()
            .subscribe(on: DispatchQueue.global(qos: .background)) // 在后台处理订阅成功后的逻辑
            .receive(on: DispatchQueue.main) // 在主线程响应位置更新
            .sink { location in
                self.handleFreeTrainingLocationUpdate(location)
            }
    }
    
    func deleteFreeTrainingLocationSubscription() {
        locationFreeTrainingCancellable?.cancel()
    }
    
    private func handleFreeTrainingLocationUpdate(_ location: CLLocation) {
        userLocation = location
    }
    
    func startFreeTraining() {
        Logger.competition.notice_public("free training start")
        // 检查 Always Location 权限
        let status = LocationManager.shared.authorizationStatus
        if status != .authorizedAlways {
            alertTitle = "competition.realtime.start.popup.no_auth"
            alertMessage = "competition.realtime.start.popup.no_auth.content"
            showAlert = true
            return
        }
        
        // 检查 GPS 强度
        guard LocationManager.shared.signalStrength.bars > 1 else {
            let toast = Toast(message: "competition.realtime.start.toast.gps")
            ToastManager.shared.show(toast: toast)
            return
        }
        startFreeTrainingSession()
    }
    
    func startFreeTrainingSession() {
        guard let sport, sportFeature?.featureType == .freeTraining else { return }
        startTime = Date()
        
        // 清理定时器任务可能残留的数据
        realtimeStatisticData = .empty
        basePathData = []
        bikeFreeTrainingPathData = []
        runningFreeTrainingPathData = []
        dataFusionManager.elapsedTime = 0
        
        isRecording = true
        
        // Start location updates
        LocationManager.shared.changeToHighUpdate()

        // Start accelerometer/gyro/magnet updates
        motionManager.startAccelerometerUpdates()
        motionManager.startGyroUpdates()
        motionManager.startMagnetometerUpdates()
        
        addDefaultDevice()
        
        // 使用定时器每1秒记录一次数据
        self.startFreeTrainingTimer()
        let sensorRequest = sensorRequest >> 1
        
        // 默认设备开始收集数据
        for (pos, dev) in deviceManager.deviceMap {
            if let device = dev, (sensorRequest & (1 << pos.rawValue)) != 0 {
                Logger.competition.notice_public("\(pos.name) watch data start collecting")
                device.startCollection(activityType: sport, locationType: "outdoor")  // 开始数据收集
            }
        }
    }
    
    private func startFreeTrainingTimer() {
        // 在比赛开始时已记录下 startTime = Date()
        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now(), repeating: 1.0) // 每1秒触发一次
        var tickCounter = 0 // 用于计数，每次事件触发加1
        
        timer.setEventHandler { [weak self] in
            guard let self = self, self.isRecording, let start = self.startTime else { return }
            
            // 更新计数器
            tickCounter += 1
            
            // 更新 elapsedTime
            let newElapsedTime = Date().timeIntervalSince(start)
            DispatchQueue.main.async {
                // 再次检查比赛状态，避免比赛结束时计时器闭包延迟更新重置elapsedTime
                if self.isRecording {
                    self.dataFusionManager.elapsedTime = newElapsedTime
                }
            }
            
            // 每3秒记录一次 path 数据
            if tickCounter % 3 == 0 && self.isRecording {
                // 当前支持的最大训练时间为 5h
                if self.dataFusionManager.elapsedTime > 18000 {
                    DispatchQueue.main.async {
                        self.stopFreeTraining()
                    }
                }
                DispatchQueue.main.async {
                    self.recordFreeTrainingPath()
                }
                tickCounter = 0 // 重置计数器
            }
        }
        self.timer = timer
        timer.resume()
        Logger.competition.notice_public("start phone free training timer.")
    }
    
    private func recordFreeTrainingPath() {
        guard let location = LocationManager.shared.getLocation() else { return }
        let basePoint = PathPoint(
            lat: location.coordinate.latitude,
            lon: location.coordinate.longitude,
            speed: location.speed,
            altitude: location.altitude,
            heart_rate: matchContext.latestHeartRate,
            timestamp: Date().timeIntervalSince1970
        )
        if let lastPoint = basePathData.last {
            let distance = horizontalDistance(from: lastPoint, to: basePoint)
            
            self.horizontalDistanceWindow += distance
            let allowElevationUpdate = horizontalDistanceWindow >= 5
            if allowElevationUpdate {
                horizontalDistanceWindow = max(0, horizontalDistanceWindow - 5)
            }
            var elevGain = 0.0
            if allowElevationUpdate {
                let smoothedAlt = smoothedAltitude(from: location.altitude)
                elevGain = smoothedAlt - matchContext.altitude
                matchContext.altitude = smoothedAlt
                pendingElevationGain = max(pendingElevationGain + elevGain, 0)
            }
            
            matchContext.speed = 3.6 * distance / 3.0
            matchContext.distance += distance
            DispatchQueue.main.async {
                self.realtimeStatisticData.distance += distance
                self.realtimeStatisticData.avgSpeed = 3.6 * self.realtimeStatisticData.distance / self.dataFusionManager.elapsedTime
                if allowElevationUpdate, self.pendingElevationGain > self.elevationThreshold {
                    self.realtimeStatisticData.elevationGain += self.pendingElevationGain
                    self.pendingElevationGain = 0
                }
            }
        }
        basePathData.append(basePoint)
        if sport == .Bike {
            let pathPoint = BikeFreeTrainingPathPoint(
                base: basePoint,
                power: matchContext.latestPower,
                pedal_cadence: matchContext.pedalCadence
            )
            bikeFreeTrainingPathData.append(pathPoint)
        } else if sport == .Running {
            let pathPoint = RunningFreeTrainingPathPoint(
                base: basePoint,
                power: matchContext.latestPower,
                step_cadence: matchContext.stepCadence,
                vertical_amplitude: nil,
                touchdown_time: nil,
                step_size: nil
            )
            runningFreeTrainingPathData.append(pathPoint)
        }
    }
    
    private func stopFreeTrainingTimer() {
        timer?.cancel()
        timer = nil
        recordFreeTrainingPath()
        Logger.competition.notice_public("stop phone training timer.")
    }
    
    func stopFreeTraining() {
        isRecording = false
        isShowWidget = false
        // Stop location updates
        deleteFreeTrainingLocationSubscription()
        LocationManager.shared.backToLastSet()
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
        motionManager.stopMagnetometerUpdates()
        
        // 停止手机和传感器设备的数据收集
        self.stopFreeTrainingTimer()
        for (pos, dev) in deviceManager.deviceMap {
            if let device = dev, (sensorRequest & (1 << (pos.rawValue + 1))) != 0 {
                Logger.competition.notice_public("\(pos.name) watch stop collecting")
                device.stopCollection()
            }
        }
        
        finishFreeTraining_server()
        
        resetCompetitionProperties()
        Logger.competition.notice_public("free training stop")
    }
    
    func finishFreeTraining_server() {
        guard let startTime else { return }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if sportFeature == .bikeFreeTraining {
            var headers: [String: String] = [:]
            headers["Content-Type"] = "application/json"
            let uploadID = UUID().uuidString
            let requestData = BikeFinishFreeTrainingRequest(
                start_time: formatter.string(from: startTime),
                end_time: formatter.string(from: Date()),
                path: bikeFreeTrainingPathData,
                client_upload_id: uploadID
            )
            guard let encodedBody = try? JSONEncoder().encode(requestData) else { return }
            let endpointPath = "/training/bike/finish_free_training"
            // 写前落盘
            savePendingUpload(id: uploadID, category: .training, mode: .freeTraining, endpointPath: endpointPath, body: encodedBody, title: nil)

            let request = APIRequest(path: endpointPath, method: .post, headers: headers, body: encodedBody, requiresAuth: true)

            NetworkService.sendRequest(with: request, decodingType: FreeTrainingFinishResponse.self, showLoadingToast: true, showErrorToast: true) { result in
                switch result {
                case .success(let data):
                    self.removePendingUpload(id: uploadID)
                    guard let unwrappedData = data else { return }
                    DispatchQueue.main.async {
                        for asset in unwrappedData.cc_rewards {
                            self.assetManager.updateCCAsset(type: asset.ccasset_type, newBalance: asset.new_ccamount)
                        }
                        PopupWindowManager.shared.presentPopup(
                            title: "training.result.complete",
                            bottomButtons: [
                                .confirm()
                            ]
                        ) {
                            VStack {
                                if unwrappedData.new_grids > 0, unwrappedData.triggered_buff_count > 0 {
                                    Text("training.result.popup.content.new_area_buff \(unwrappedData.new_grids) \(unwrappedData.triggered_buff_count)")
                                        .fontWeight(.bold)
                                } else if unwrappedData.new_grids > 0 {
                                    Text("training.result.popup.content.new_area \(unwrappedData.new_grids)")
                                        .fontWeight(.bold)
                                } else if unwrappedData.triggered_buff_count > 0 {
                                    Text("training.result.popup.content.buff \(unwrappedData.triggered_buff_count)")
                                        .fontWeight(.bold)
                                }
                                XPProgressView(beforeXP: unwrappedData.xp_before, deltaXP: unwrappedData.xp_delta)
                                TrainingStateProgressView(beforeState: unwrappedData.training_state_before, deltaState: unwrappedData.training_state_delta)
                                HStack(spacing: 10) {
                                    ForEach(unwrappedData.cc_rewards) { reward in
                                        HStack(spacing: 4) {
                                            Image(reward.ccasset_type.iconName)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 20)
                                            Text("+ \(reward.reward_amount)")
                                                .font(.system(size: 15))
                                                .fontWeight(.semibold)
                                        }
                                    }
                                }
                                .padding(.top, 10)
                            }
                            .foregroundStyle(Color.white)
                        }
                        self.navigationManager.append(.bikeFreeTrainingRecordDetailView(recordID: unwrappedData.record_id))
                    }
                    GlobalConfig.shared.refreshFamiliarity = true
                    GlobalConfig.shared.refreshFreeTrainingView = true
                case .failure(let error):
                    switch error {
                    case .businessError:
                        self.removePendingUpload(id: uploadID)
                    default:
                        self.notifyPendingUploadSaved()
                    }
                    DispatchQueue.main.async {
                        if let index = self.navigationManager.path.firstIndex(where: { $0.string == "freeTrainingRealtimeView" }) {
                            let lastToRemove = self.navigationManager.path.count - index
                            self.navigationManager.removeLast(lastToRemove)
                        } else {
                            return
                        }
                    }
                }
            }
        } else if sportFeature == .runningFreeTraining {
            var headers: [String: String] = [:]
            headers["Content-Type"] = "application/json"
            let uploadID = UUID().uuidString
            let requestData = RunningFinishFreeTrainingRequest(
                start_time: formatter.string(from: startTime),
                end_time: formatter.string(from: Date()),
                path: runningFreeTrainingPathData,
                client_upload_id: uploadID
            )
            guard let encodedBody = try? JSONEncoder().encode(requestData) else { return }
            let endpointPath = "/training/running/finish_free_training"
            // 写前落盘
            savePendingUpload(id: uploadID, category: .training, mode: .freeTraining, endpointPath: endpointPath, body: encodedBody, title: nil)

            let request = APIRequest(path: endpointPath, method: .post, headers: headers, body: encodedBody, requiresAuth: true)

            NetworkService.sendRequest(with: request, decodingType: FreeTrainingFinishResponse.self, showLoadingToast: true, showErrorToast: true) { result in
                switch result {
                case .success(let data):
                    self.removePendingUpload(id: uploadID)
                    guard let unwrappedData = data else { return }
                    DispatchQueue.main.async {
                        for asset in unwrappedData.cc_rewards {
                            self.assetManager.updateCCAsset(type: asset.ccasset_type, newBalance: asset.new_ccamount)
                        }
                        PopupWindowManager.shared.presentPopup(
                            title: "training.result.complete",
                            bottomButtons: [
                                .confirm()
                            ]
                        ) {
                            VStack {
                                if unwrappedData.new_grids > 0, unwrappedData.triggered_buff_count > 0 {
                                    Text("training.result.popup.content.new_area_buff \(unwrappedData.new_grids) \(unwrappedData.triggered_buff_count)")
                                        .fontWeight(.bold)
                                } else if unwrappedData.new_grids > 0 {
                                    Text("training.result.popup.content.new_area \(unwrappedData.new_grids)")
                                        .fontWeight(.bold)
                                } else if unwrappedData.triggered_buff_count > 0 {
                                    Text("training.result.popup.content.buff \(unwrappedData.triggered_buff_count)")
                                        .fontWeight(.bold)
                                }
                                XPProgressView(beforeXP: unwrappedData.xp_before, deltaXP: unwrappedData.xp_delta)
                                TrainingStateProgressView(beforeState: unwrappedData.training_state_before, deltaState: unwrappedData.training_state_delta)
                                HStack(spacing: 10) {
                                    ForEach(unwrappedData.cc_rewards) { reward in
                                        HStack(spacing: 4) {
                                            Image(reward.ccasset_type.iconName)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 20)
                                            Text("+ \(reward.reward_amount)")
                                                .font(.system(size: 15))
                                                .fontWeight(.semibold)
                                        }
                                    }
                                }
                                .padding(.top, 10)
                            }
                            .foregroundStyle(Color.white)
                        }
                        self.navigationManager.append(.runningFreeTrainingRecordDetailView(recordID: unwrappedData.record_id))
                    }
                    GlobalConfig.shared.refreshFamiliarity = true
                    GlobalConfig.shared.refreshFreeTrainingView = true
                case .failure(let error):
                    switch error {
                    case .businessError:
                        self.removePendingUpload(id: uploadID)
                    default:
                        self.notifyPendingUploadSaved()
                    }
                    DispatchQueue.main.async {
                        if let index = self.navigationManager.path.firstIndex(where: { $0.string == "freeTrainingRealtimeView" }) {
                            let lastToRemove = self.navigationManager.path.count - index
                            self.navigationManager.removeLast(lastToRemove)
                        } else {
                            return
                        }
                    }
                }
            }
        }
    }
}

// 路线训练模式
extension CompetitionManager {
    func resetBikeRouteEnv(route: BikeRouteEnv) {
        sportFeature = .bikeRouteTraining
        currentBikeRoute = route
    }
    
    func resetRunningRouteEnv(route: RunningRouteEnv) {
        //print("set env! \(route.routePoints)")
        sportFeature = .runningRouteTraining
        currentRunningRoute = route
    }
    
    func setupRouteTrainingLocationSubscription() {
        locationRouteTrainingCancellable = LocationManager.shared.locationPublisher()
            .subscribe(on: DispatchQueue.global(qos: .background)) // 在后台处理订阅成功后的逻辑
            .receive(on: DispatchQueue.main) // 在主线程响应位置更新
            .sink { location in
                self.handleRouteTrainingLocationUpdate(location)
            }
    }
    
    func deleteRouteTrainingLocationSubscription() {
        locationRouteTrainingCancellable?.cancel()
    }
    
    private func handleRouteTrainingLocationUpdate(_ location: CLLocation) {
        var routePoints: [RoutePointRealtime] = []
        if let route = currentBikeRoute?.routePoints, sportFeature == .bikeRouteTraining {
            routePoints = route
        } else if let route = currentRunningRoute?.routePoints, sportFeature == .runningRouteTraining {
            routePoints = route
        } else {
            return
        }
        
        userLocation = location
        if isRecording {
            // 运动进行中，实时检查并更新每个检查点（包括终点），同时更新路径中的检查点状态
            guard let nextCPIndex = nextCheckPointIndex, nextCPIndex < routePoints.count else {
                return
            }
            for index in nextCPIndex..<routePoints.count {
                // 找到当前需要检测的 checkpoint
                guard case .checkpoint(var checkpoint) = routePoints[index] else { return }
                // 已经 check 或 miss 就跳过（防御）
                if checkpoint.isCheck || checkpoint.isMiss { continue }
                
                let distance = location.distance(from: CLLocation(latitude: checkpoint.lat, longitude: checkpoint.lng))
                // 中间检查点 3米 容错
                let radius: Double = (index == routePoints.count - 1) ? checkpoint.radius : (checkpoint.radius + 3.0)
                
                if distance <= radius {
                    // 终点
                    if index == routePoints.count - 1 {
                        DispatchQueue.main.async {
                            self.stopRouteTraining()
                        }
                        return
                    }
                    
                    checkpoint.isCheck = true
                    routePoints[index] = .checkpoint(checkpoint)
                    
                    // 前面所有未完成 checkpoint 标记 miss
                    if index > nextCPIndex {
                        for missIndex in nextCPIndex..<index {
                            guard case .checkpoint(var misspoint) = routePoints[missIndex] else { return }
                            if !misspoint.isCheck && !misspoint.isMiss {
                                misspoint.isMiss = true
                                routePoints[missIndex] = .checkpoint(misspoint)
                            }
                        }
                    }
                    
                    DispatchQueue.main.async {
                        if self.sportFeature == .bikeRouteTraining {
                            self.currentBikeRoute?.routePoints = routePoints
                        } else if self.sportFeature == .runningRouteTraining {
                            self.currentRunningRoute?.routePoints = routePoints
                        }
                        self.nextCheckPointIndex = index + 1
                    }
                    break
                }
            }
        } else {
            // 运动开始前，检查用户是否在起点的检查区域内
            //print("handleRouteTrainingLocationUpdate!")
            guard let start = routePoints.first,
                    case .checkpoint(let cp) = start else { return }
            //print(currentBikeRoute?.routePoints)
            let distance = location.distance(from: CLLocation(latitude: cp.lat, longitude: cp.lng))
            //print(distance)
            DispatchQueue.main.async {
                self.isInValidArea = distance <= cp.radius
            }
        }
    }
    
    func startRouteTraining() {
        Logger.competition.notice_public("route training start")
        // 检查 Always Location 权限
        let status = LocationManager.shared.authorizationStatus
        if status != .authorizedAlways {
            alertTitle = "competition.realtime.start.popup.no_auth"
            alertMessage = "competition.realtime.start.popup.no_auth.content"
            showAlert = true
            return
        }
        
        // 检查 GPS 强度
        guard LocationManager.shared.signalStrength.bars > 1 else {
            let toast = Toast(message: "competition.realtime.start.toast.gps")
            ToastManager.shared.show(toast: toast)
            return
        }
        startRouteTrainingSession()
    }
    
    func startRouteTrainingSession() {
        guard let sport, sportFeature?.featureType == .routeTraining else { return }
        fetchPaceBaseline()
        var routePoints: [RoutePointRealtime]
        var startPoint: CheckpointRealtime
        if sportFeature == .bikeRouteTraining, let route = currentBikeRoute?.routePoints, case .checkpoint(let point) = route[0] {
            routePoints = route
            startPoint = point
        } else if sportFeature == .runningRouteTraining, let route = currentRunningRoute?.routePoints, case .checkpoint(let point) = route[0] {
            routePoints = route
            startPoint = point
        } else {
            return
        }
        
        startTime = Date()
        
        // 清理定时器任务可能残留的数据
        realtimeStatisticData = .empty
        basePathData = []
        bikeRouteTrainingPathData = []
        runningRouteTrainingPathData = []
        dataFusionManager.elapsedTime = 0
        
        eventBus.emit(.matchStart, context: matchContext)
        
        isRecording = true
        
        // 更新起点的检查状态 & 更新下一个检查点
        startPoint.isCheck = true
        routePoints[0] = .checkpoint(startPoint)
        if sportFeature == .bikeRouteTraining {
            currentBikeRoute?.routePoints = routePoints
        } else if sportFeature == .runningRouteTraining {
            currentRunningRoute?.routePoints = routePoints
        }
        nextCheckPointIndex = 1
        
        // Start location updates
        LocationManager.shared.changeToHighUpdate()

        // Start accelerometer/gyro/magnet updates
        motionManager.startAccelerometerUpdates()
        motionManager.startGyroUpdates()
        motionManager.startMagnetometerUpdates()
        
        // 使用定时器每0.05秒记录一次数据
        self.startRouteTrainingTimer()
        let isNeedPhoneData = sensorRequest & 0b000001 != 0
        let sensorRequest = sensorRequest >> 1
        
        // 所有设备开始收集数据
        if isNeedPhoneData {
            dataFusionManager.deviceNeedToWork |= 0b000001
        }
        for (pos, dev) in deviceManager.deviceMap {
            if let device = dev, (sensorRequest & (1 << pos.rawValue)) != 0 {
                // 当前 dataFusionManager.deviceNeedToWork 和 device.enableIMU 信息交给 each cards 配置
                //dataFusionManager.deviceNeedToWork |= (1 << (pos.rawValue + 1))
                //startCollecting(device: device)
                Logger.competition.notice_public("\(pos.name) watch data start collecting")
                device.startCollection(activityType: sport, locationType: "outdoor")  // 开始数据收集
            }
        }
    }
    
    private func startRouteTrainingTimer() {
        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now(), repeating: 0.05) // 每0.05秒触发一次
        var tickCounter = 0 // 用于计数，每次事件触发加1
        
        timer.setEventHandler { [weak self] in
            guard let self = self, self.isRecording, let start = self.startTime else { return }
            
            // 记录 phone 端数据
            if self.sensorRequest & 0b000001 != 0 && self.isRecording {
                self.recordMotionData()
            }
            
            // 更新计数器
            tickCounter += 1
            
            // 每 1 秒更新 elapsedTime
            if tickCounter % 20 == 0 { // 20 * 0.05s = 1s
                let newElapsedTime = Date().timeIntervalSince(start)
                DispatchQueue.main.async {
                    // 再次检查比赛状态，避免比赛结束时计时器闭包延迟更新重置elapsedTime
                    if self.isRecording {
                        self.dataFusionManager.elapsedTime = newElapsedTime
                    }
                }
            }
            
            // 每 3 秒记录一次 path 数据 & 发出 matchCycleUpdate 信号
            if tickCounter % 60 == 0 && self.isRecording {
                // 5h 兜底
                if self.dataFusionManager.elapsedTime > 18000 {
                    DispatchQueue.main.async {
                        self.stopRouteTraining()
                    }
                }
                DispatchQueue.main.async {
                    self.recordRouteTrainingPath()
                }
                eventBus.emit(.matchCycleUpdate, context: matchContext)
                tickCounter = 0 // 重置计数器
            }
        }
        self.timer = timer
        timer.resume()
        Logger.competition.notice_public("start phone route training timer.")
    }
    
    private func recordRouteTrainingPath() {
        guard let location = LocationManager.shared.getLocation() else { return }
        let basePoint = PathPoint(
            lat: location.coordinate.latitude,
            lon: location.coordinate.longitude,
            speed: location.speed,
            altitude: location.altitude,
            heart_rate: matchContext.latestHeartRate,
            timestamp: Date().timeIntervalSince1970
        )
        if let lastPoint = basePathData.last {
            let distance = horizontalDistance(from: lastPoint, to: basePoint)
            
            self.horizontalDistanceWindow += distance
            let allowElevationUpdate = horizontalDistanceWindow >= 5
            if allowElevationUpdate {
                horizontalDistanceWindow = max(0, horizontalDistanceWindow - 5)
            }
            var elevGain = 0.0
            if allowElevationUpdate {
                let smoothedAlt = smoothedAltitude(from: location.altitude)
                elevGain = smoothedAlt - matchContext.altitude
                matchContext.altitude = smoothedAlt
                pendingElevationGain = max(pendingElevationGain + elevGain, 0)
            }
            
            matchContext.speed = 3.6 * distance / 3.0
            matchContext.distance += distance
            DispatchQueue.main.async {
                self.realtimeStatisticData.distance += distance
                self.realtimeStatisticData.avgSpeed = 3.6 * self.realtimeStatisticData.distance / self.dataFusionManager.elapsedTime
                if allowElevationUpdate, self.pendingElevationGain > self.elevationThreshold {
                    self.realtimeStatisticData.elevationGain += self.pendingElevationGain
                    self.pendingElevationGain = 0
                }
            }
        }
        self.basePathData.append(basePoint)
        updatePaceEstimate(coord: location.coordinate)
        if sport == .Bike {
            let pathPoint = BikeRouteTrainingPathPoint(
                base: basePoint,
                power: matchContext.latestPower,
                pedal_cadence: matchContext.pedalCadence,
                card_bonus: matchContext.bonusEachCards
            )
            bikeRouteTrainingPathData.append(pathPoint)
        } else if sport == .Running {
            let pathPoint = RunningRouteTrainingPathPoint(
                base: basePoint,
                power: matchContext.latestPower,
                step_cadence: matchContext.stepCadence,
                vertical_amplitude: nil,
                touchdown_time: nil,
                step_size: nil,
                card_bonus: matchContext.bonusEachCards
            )
            runningRouteTrainingPathData.append(pathPoint)
        }
    }
    
    private func stopRouteTrainingTimer() {
        timer?.cancel()
        timer = nil
        recordRouteTrainingPath()
        Logger.competition.notice_public("stop phone route training timer.")
    }
    
    func stopRouteTraining() {
        isRecording = false
        isShowWidget = false
        // Stop location updates
        deleteRouteTrainingLocationSubscription()
        LocationManager.shared.backToLastSet()
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
        motionManager.stopMagnetometerUpdates()
        
        // 停止手机和传感器设备的数据收集
        self.stopRouteTrainingTimer()
        for (pos, dev) in deviceManager.deviceMap {
            if let device = dev, (sensorRequest & (1 << (pos.rawValue + 1))) != 0 {
                //stopCollecting(device: device)
                Logger.competition.notice_public("\(pos.name) watch stop collecting")
                device.stopCollection()
            }
        }
        
        eventBus.emit(.matchEnd, context: matchContext)
        
        finishRouteTraining_server()
        
        resetCompetitionProperties()
        Logger.competition.notice_public("route training stop")
    }
    
    func finishRouteTraining_server() {
        guard let startTime else { return }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let routeID = currentBikeRoute?.routeID, sportFeature == .bikeRouteTraining {
            var headers: [String: String] = [:]
            headers["Content-Type"] = "application/json"
            let uploadID = UUID().uuidString
            let requestData = BikeFinishRouteTrainingRequest(
                route_id: routeID,
                start_time: formatter.string(from: startTime),
                end_time: formatter.string(from: Date()),
                path: bikeRouteTrainingPathData,
                bonus_in_cards: matchContext.bonusEachCards,
                client_upload_id: uploadID
            )
            guard let encodedBody = try? JSONEncoder().encode(requestData) else { return }
            let endpointPath = "/training/bike/finish_route_training"
            // 写前落盘
            savePendingUpload(id: uploadID, category: .training, mode: .routeTraining, endpointPath: endpointPath, body: encodedBody, title: currentBikeRoute?.title)

            let request = APIRequest(path: endpointPath, method: .post, headers: headers, body: encodedBody, requiresAuth: true)

            NetworkService.sendRequest(with: request, decodingType: RouteTrainingFinishResponse.self, showLoadingToast: true, showErrorToast: true) { result in
                switch result {
                case .success(let data):
                    self.removePendingUpload(id: uploadID)
                    guard let unwrappedData = data else { return }
                    DispatchQueue.main.async {
                        for asset in unwrappedData.cc_rewards {
                            self.assetManager.updateCCAsset(type: asset.ccasset_type, newBalance: asset.new_ccamount)
                        }
                        PopupWindowManager.shared.presentPopup(
                            title: "training.result.complete",
                            bottomButtons: [
                                .confirm()
                            ]
                        ) {
                            VStack {
                                if unwrappedData.new_grids > 0 {
                                    Text("training.result.popup.content.new_area \(unwrappedData.new_grids)")
                                        .fontWeight(.bold)
                                }
                                XPProgressView(beforeXP: unwrappedData.xp_before, deltaXP: unwrappedData.xp_delta)
                                TrainingStateProgressView(beforeState: unwrappedData.training_state_before, deltaState: unwrappedData.training_state_delta)
                                HStack(spacing: 10) {
                                    ForEach(unwrappedData.cc_rewards) { reward in
                                        HStack(spacing: 4) {
                                            Image(reward.ccasset_type.iconName)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 20)
                                            Text("+ \(reward.reward_amount)")
                                                .font(.system(size: 15))
                                                .fontWeight(.semibold)
                                        }
                                    }
                                }
                                .padding(.top, 10)
                            }
                            .foregroundStyle(Color.white)
                        }
                        self.navigationManager.append(.bikeRouteTrainingRecordDetailView(recordID: unwrappedData.record_id))
                    }
                case .failure(let error):
                    switch error {
                    case .businessError:
                        self.removePendingUpload(id: uploadID)
                    default:
                        self.notifyPendingUploadSaved()
                    }
                    DispatchQueue.main.async {
                        var cardSelectViewIndex = 0
                        var realtimeViewIndex = 0
                        if let index = self.navigationManager.path.firstIndex(where: { $0.string == "competitionCardSelectView" }) {
                            cardSelectViewIndex = self.navigationManager.path.count - index
                        }
                        if let index = self.navigationManager.path.firstIndex(where: { $0.string == "routeTrainingRealtimeView" }) {
                            realtimeViewIndex = self.navigationManager.path.count - index
                        }
                        let lastToRemove = max(cardSelectViewIndex, realtimeViewIndex)
                        self.navigationManager.removeLast(lastToRemove)
                    }
                }
            }
        } else if let routeID = currentRunningRoute?.routeID, sportFeature == .runningRouteTraining {
            var headers: [String: String] = [:]
            headers["Content-Type"] = "application/json"
            let uploadID = UUID().uuidString
            let requestData = RunningFinishRouteTrainingRequest(
                route_id: routeID,
                start_time: formatter.string(from: startTime),
                end_time: formatter.string(from: Date()),
                path: runningRouteTrainingPathData,
                bonus_in_cards: matchContext.bonusEachCards,
                client_upload_id: uploadID
            )
            guard let encodedBody = try? JSONEncoder().encode(requestData) else { return }
            let endpointPath = "/training/running/finish_route_training"
            // 写前落盘
            savePendingUpload(id: uploadID, category: .training, mode: .routeTraining, endpointPath: endpointPath, body: encodedBody, title: currentRunningRoute?.title)

            let request = APIRequest(path: endpointPath, method: .post, headers: headers, body: encodedBody, requiresAuth: true)

            NetworkService.sendRequest(with: request, decodingType: RouteTrainingFinishResponse.self, showLoadingToast: true, showErrorToast: true) { result in
                switch result {
                case .success(let data):
                    self.removePendingUpload(id: uploadID)
                    guard let unwrappedData = data else { return }
                    DispatchQueue.main.async {
                        for asset in unwrappedData.cc_rewards {
                            self.assetManager.updateCCAsset(type: asset.ccasset_type, newBalance: asset.new_ccamount)
                        }
                        PopupWindowManager.shared.presentPopup(
                            title: "training.result.complete",
                            bottomButtons: [
                                .confirm()
                            ]
                        ) {
                            VStack {
                                if unwrappedData.new_grids > 0 {
                                    Text("training.result.popup.content.new_area \(unwrappedData.new_grids)")
                                        .fontWeight(.bold)
                                }
                                XPProgressView(beforeXP: unwrappedData.xp_before, deltaXP: unwrappedData.xp_delta)
                                TrainingStateProgressView(beforeState: unwrappedData.training_state_before, deltaState: unwrappedData.training_state_delta)
                                HStack(spacing: 10) {
                                    ForEach(unwrappedData.cc_rewards) { reward in
                                        HStack(spacing: 4) {
                                            Image(reward.ccasset_type.iconName)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 20)
                                            Text("+ \(reward.reward_amount)")
                                                .font(.system(size: 15))
                                                .fontWeight(.semibold)
                                        }
                                    }
                                }
                                .padding(.top, 10)
                            }
                            .foregroundStyle(Color.white)
                        }
                        self.navigationManager.append(.runningRouteTrainingRecordDetailView(recordID: unwrappedData.record_id))
                    }
                case .failure(let error):
                    switch error {
                    case .businessError:
                        self.removePendingUpload(id: uploadID)
                    default:
                        self.notifyPendingUploadSaved()
                    }
                    DispatchQueue.main.async {
                        var cardSelectViewIndex = 0
                        var realtimeViewIndex = 0
                        if let index = self.navigationManager.path.firstIndex(where: { $0.string == "competitionCardSelectView" }) {
                            cardSelectViewIndex = self.navigationManager.path.count - index
                        }
                        if let index = self.navigationManager.path.firstIndex(where: { $0.string == "routeTrainingRealtimeView" }) {
                            realtimeViewIndex = self.navigationManager.path.count - index
                        }
                        let lastToRemove = max(cardSelectViewIndex, realtimeViewIndex)
                        self.navigationManager.removeLast(lastToRemove)
                    }
                }
            }
        }
    }
}

extension CompetitionManager {
    // 切到前台刷新 widget 状态
    func syncWidgetVisibility() {
        if !isRecording {
            isShowWidget = false
        }
    }
}

// 运动数据处理
extension CompetitionManager {
    // 海拔平滑
    func smoothedAltitude(from rawAltitude: Double) -> Double {
        recentAltitudeSamples.append(rawAltitude)
        if recentAltitudeSamples.count > altitudeSmoothingWindow {
            recentAltitudeSamples.removeFirst()
        }
        return recentAltitudeSamples.reduce(0, +) / Double(recentAltitudeSamples.count)
    }
    
    // 计算两点之间的距离（包含高度差），单位 m
    func horizontalDistance(from p1: PathPoint, to p2: PathPoint) -> Double {
        let loc1 = CLLocation(latitude: p1.lat, longitude: p1.lon)
        let loc2 = CLLocation(latitude: p2.lat, longitude: p2.lon)
        return loc1.distance(from: loc2)
    }
    
    // 计算路径的总距离（累计每段距离），单位 m
    func computeTotalDistance(path: [PathPoint]) -> Double {
        guard path.count >= 2 else { return 0.0 }
        var total: Double = 0
        for i in 1..<path.count {
            total += horizontalDistance(from: path[i-1], to: path[i])
        }
        return total
    }
    
    // 根据固定窗口距离（如每 100m）或点数窗口计算每段速度（km/h）
    func computeSegmentSpeeds(path: [PathPoint], windowMeters: Double = 100.0) -> [Double] {
        var speeds: [Double] = []
        guard path.count > 1 else { return speeds }
        
        var accumulatedDistance: Double = 0.0
        var windowStartTime: TimeInterval = path.first!.timestamp
        
        for i in 1..<path.count {
            let p1 = path[i - 1]
            let p2 = path[i]
            
            let dist = horizontalDistance(from: p1, to: p2)
            accumulatedDistance += dist
            
            if accumulatedDistance >= windowMeters {
                let totalTime = p2.timestamp - windowStartTime
                if totalTime > 0 {
                    let speed = (accumulatedDistance / totalTime) * 3.6
                    speeds.append(speed)
                }
                accumulatedDistance = 0
                windowStartTime = p2.timestamp
            }
        }
        return speeds
    }
    
    // 计算坡度统计（每段上坡/下坡坡度）
    struct SlopeStats {
        let maxSlope: Double  // 最大坡度 (绝对值)
        let avgSlope: Double
    }
    
    func computeSlopeStats(path: [PathPoint]) -> SlopeStats {
        let n = path.count
        guard n >= 2 else {
            return SlopeStats(maxSlope: 0, avgSlope: 0)
        }
        var sumSlope: Double = 0
        var count: Double = 0
        var maxAbsSlope: Double = 0
        
        for i in 1..<n {
            let dHoriz = horizontalDistance(from: path[i-1], to: path[i])
            let dAlt = path[i].altitude - path[i-1].altitude  // 高度差，单位 m
            if dHoriz > 0 {
                let slope = dAlt / dHoriz  // 斜率：高度差 / 距离 (单位：无量纲)
                sumSlope += slope
                count += 1
                maxAbsSlope = max(maxAbsSlope, abs(slope))
            }
        }
        let avgSlope = count > 0 ? sumSlope / count : 0
        return SlopeStats(maxSlope: maxAbsSlope, avgSlope: avgSlope)
    }
    
    // 检测海拔是否有非正常跃变（例如两点高度跳跃 > 某阈值，比如 50m 或类似极端值）
    func detectElevationJump(elevs: [Double], maxJump: Double = 50.0) -> Bool {
        // 如果任何相邻两点高度差绝对值 > maxJump，则视为跳跃异常
        for i in 1..<elevs.count {
            if abs(elevs[i] - elevs[i-1]) > maxJump {
                return true
            }
        }
        return false
    }
    
    // 统计 GPS 跳变次数：即相邻两点依据时间算出的速度如果大于合理上限
    func countGpsJumps(path: [PathPoint], maxReasonableKmh: Double = 100.0) -> Int {
        let threshold = maxReasonableKmh  // km/h
        var count = 0
        for i in 1..<path.count {
            let dist = horizontalDistance(from: path[i-1], to: path[i])
            let dt = path[i].timestamp - path[i-1].timestamp
            if dt > 0 {
                let v_m_s = dist / dt
                let v_kmh = v_m_s * 3.6
                if v_kmh > threshold {
                    count += 1
                }
            }
        }
        return count
    }
    
    // 功率／心率一致性检测示例（非常粗略的经验公式）
//    func isPowerConsistent(speed kmh: Double, power: Double) -> Bool {
//        // 假设功率与速度呈现某种关系，这里举例一个简单比值判断：
//        // 如果用户以极高速度但功率极低，就认为不一致
//        // 真实模型要根据空气阻力、风阻、车重、坡度等计算
//        let minimalExpectedPower = kmh * 2.0  // 经验系数（kmh × 2）
//        return power >= minimalExpectedPower
//    }
}

// 本地调试链路(未完成)
#if DEBUG
extension CompetitionManager {
    func startCompetitionSession_debug(with feature: SportFeature) {
        //guard let sport else { return }
        sportFeature = feature
        let testRouteData = (try? JSONDecoder().decode(JSONValue.self, from: Data("{\"type\":\"pointToPoint\",\"steps\":[]}".utf8))) ?? JSONValue.null
        let testDTO = BikeRaceRecordDTO(record_id: "", region_id: "", event_name: "", track_name: "", route_type: .pointToPoint, route_data: testRouteData, track_end_date: "", status: .notStarted, start_date: nil, end_date: nil, duration_seconds: nil, is_team: false, team_title: nil, team_competition_date: nil, created_at: "")
        currentBikeRecord = BikeRaceRecord(from: testDTO)
        loadMatchEnv()
        startTime = Date()
        startCompetitionSession()
    }
    
    func stopCompetition_debug() {
        isRecording = false
        // Stop location updates
        deleteCompetitionLocationSubscription()
        LocationManager.shared.backToLastSet()
        //locationManager.stopUpdatingHeading()
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
        motionManager.stopMagnetometerUpdates()
        
        // Stop audio recording if applicable
        //stopRecordingAudio()
        
        // 停止手机和传感器设备的数据收集
        self.stopTimer()
        for (pos, dev) in deviceManager.deviceMap {
            if let device = dev, (sensorRequest & (1 << (pos.rawValue + 1))) != 0 {
                //stopCollecting(device: device)
                Logger.competition.notice_public("\(pos.name) watch stop collecting")
                device.stopCollection()
            }
        }
        
        if SAVEPHONERAWDATA {
            self.finalizeCompetitionData()
        }
        eventBus.emit(.matchEnd, context: matchContext)
        
        if DUMPMATCHDATA {
            basePathData_debug = basePathData
            bikePathData_debug = bikePathData
            runningPathData_debug = runningPathData
        }
        resetCompetitionProperties()
        Logger.competition.notice_public("debug competition stop")
    }
    
    // 保存批次数据为CSV
    private func saveBatchAsCSV(dataBatch: [PhoneData]) {
        // 定义CSV文件路径
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent("competitionData_phone_raw.csv")
        
        // 如果文件不存在，创建并写入头部
        if !fileManager.fileExists(atPath: fileURL.path) {
            let csvHeader = "timestamp,altitude,speed,acc_x,acc_y,acc_z,gyro_x,gyro_y,gyro_z,mag_x,mag_y,mag_z,audioSample\n"
            do {
                try csvHeader.write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                Logger.competition.notice_public("Failed to write CSV header: \(error)")
                return
            }
        }
        
        // 构建CSV内容
        var csvString = ""
        
        for data in dataBatch {
            let timestamp = data.timestamp
            let altitude = data.altitude
            let speed = data.speed
            let accX = data.accX
            let accY = data.accY
            let accZ = data.accZ
            let gyroX = data.gyroX
            let gyroY = data.gyroY
            let gyroZ = data.gyroZ
            let magX = data.magX
            let magY = data.magY
            let magZ = data.magZ
            let audioSample = data.audioSample ? "1" : "0" // 简单表示有无音频数据
            
            let row = "\(timestamp),\(altitude),\(speed),\(accX),\(accY),\(accZ),\(gyroX),\(gyroY),\(gyroZ),\(magX),\(magY),\(magZ),\(audioSample)\n"
            csvString.append(row)
        }
        
        // 追加到CSV文件
        if let dataToAppend = csvString.data(using: .utf8) {
            do {
                let fileHandle = try FileHandle(forWritingTo: fileURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(dataToAppend)
                fileHandle.closeFile()
                Logger.competition.notice_public("phone batch saved as CSV.")
            } catch {
                Logger.competition.notice_public("phone failed to append CSV: \(error)")
            }
        }
    }
    
    // 结束比赛，保存剩余数据
    private func finalizeCompetitionData() {
        if competitionData.isEmpty { return }
        
        let batch = competitionData
        competitionData.removeAll()
        saveBatchAsCSV(dataBatch: batch)
        Logger.competition.notice_public("phone data finalized.")
    }
}
#endif

class MatchEventBus {
    typealias EventHandler = (MatchContext) -> Void
    private var listeners: [MatchEvent: [EventHandler]] = [:]
    
    func on(_ event: MatchEvent, handler: @escaping EventHandler) {
        listeners[event, default: []].append(handler)
    }
    
    func emit(_ event: MatchEvent, context: MatchContext) {
        listeners[event]?.forEach { $0(context) }
    }
    
    func reset() {
        listeners.removeAll()
    }
}

enum MatchEvent {
    case matchStart
    case matchCycleUpdate
    case matchIMUSensorUpdate
    case matchEnd
}

class MatchContext {
    var sportFeature: SportFeature?
    var isTeam: Bool
    var distance: Double        // 累计距离/m
    var speed: Double           // 实时速度 km/h
    var altitude: Double        // 实时海拔 m
    
    var latestHeartRate: Double?
    var latestPower: Double?
    var avgHeartRate: Double?
    var totalEnergy: Double?
    var avgPower: Double?
    var pedalCadence: Double?
    var estimatePedal: Double
    var stepCadence: Double?
    var estimateStep: Double
    
    var sensorData: DataSnapshot
    var bonusEachCards: [CardBonusItem]
    var teamBonus: TeamMagicCardBonusItem?
    
    init() {
        self.sportFeature = nil
        self.isTeam = false
        self.distance = 0
        self.speed = 0
        self.altitude = 0
        self.latestHeartRate = nil
        self.latestPower = nil
        self.avgHeartRate = nil
        self.totalEnergy = nil
        self.avgPower = nil
        self.pedalCadence = nil
        self.estimatePedal = 0
        self.stepCadence = nil
        self.estimateStep = 0
        self.sensorData = DataSnapshot(phoneSlice: [], sensorSlice: [], predictTime: 0)
        self.bonusEachCards = []
        self.teamBonus = nil
    }
    
    func reset() {
        self.sportFeature = nil
        isTeam = false
        distance = 0
        speed = 0
        altitude = 0
        latestHeartRate = nil
        latestPower = nil
        avgHeartRate = nil
        totalEnergy = nil
        avgPower = nil
        pedalCadence = nil
        estimatePedal = 0
        stepCadence = nil
        estimateStep = 0
        sensorData = DataSnapshot(phoneSlice: [], sensorSlice: [], predictTime: 0)
        bonusEachCards = []
        teamBonus = nil
    }
    
    func addOrUpdateBonus(cardID: String, bonus: Double) {
        if let idx = bonusEachCards.firstIndex(where: { $0.card_id == cardID }) {
            bonusEachCards[idx].bonus_time += bonus
        } else {
            bonusEachCards.append(CardBonusItem(card_id: cardID, bonus_time: bonus))
        }
    }
    
    func addOrUpdateTeamBonusTime(cardID: String, bonusTime: Double) {
        if teamBonus == nil {
            teamBonus = TeamMagicCardBonusItem(
                card_id: cardID,
                bonus_ratio: nil,
                bonus_seconds: 0
            )
        }
        teamBonus!.bonus_seconds = (teamBonus!.bonus_seconds ?? 0) + bonusTime
    }
}

struct TeamExpiredResponse: Codable {
    let expired_date: String?
}

struct PathPoint: Codable {
    let lat: Double
    let lon: Double
    let speed: Double
    let altitude: Double
    let heart_rate: Double?
    let timestamp: TimeInterval
}

struct BikePathPoint: Codable {
    let base: PathPoint
    
    let power: Double?
    let pedal_cadence: Double?
    let estimate_pedal_count: Double    // 预测的踏频用于校验
    
    let card_bonus: [CardBonusItem]
}

struct RunningPathPoint: Codable {
    let base: PathPoint
    
    let power: Double?
    let step_cadence: Double?
    let vertical_amplitude: Double?
    let touchdown_time: Double?
    let step_size: Double?
    let estimate_step_count: Double     // 预测的步频用于校验
    
    let card_bonus: [CardBonusItem]
}

struct BikeFreeTrainingPathPoint: Codable {
    let base: PathPoint
    
    let power: Double?
    let pedal_cadence: Double?
}

struct RunningFreeTrainingPathPoint: Codable {
    let base: PathPoint
    
    let power: Double?
    let step_cadence: Double?
    let vertical_amplitude: Double?
    let touchdown_time: Double?
    let step_size: Double?
}

struct BikeRouteTrainingPathPoint: Codable {
    let base: PathPoint
    
    let power: Double?
    let pedal_cadence: Double?
    let card_bonus: [CardBonusItem]
}

struct RunningRouteTrainingPathPoint: Codable {
    let base: PathPoint
    
    let power: Double?
    let step_cadence: Double?
    let vertical_amplitude: Double?
    let touchdown_time: Double?
    let step_size: Double?
    let card_bonus: [CardBonusItem]
}

struct CardBonusItem: Codable {
    let card_id: String
    var bonus_time: Double
}

struct TeamMagicCardBonusItem: Codable {
    let card_id: String
    var bonus_ratio: Double?
    var bonus_seconds: Double?
}

struct BikeFinishMatchRequest: Codable {
    let validation_score: Double
    let record_id: String
    let end_time: String
    let bonus_in_cards: [CardBonusItem]
    let team_bonus: TeamMagicCardBonusItem?
    let path: [BikePathPoint]
    let client_upload_id: String        // 客户端生成的幂等键，供服务端去重
}

struct RunningFinishMatchRequest: Codable {
    let validation_score: Double
    let record_id: String
    let end_time: String
    let bonus_in_cards: [CardBonusItem]
    let team_bonus: TeamMagicCardBonusItem?
    let path: [RunningPathPoint]
    let client_upload_id: String        // 客户端生成的幂等键，供服务端去重
}

struct MatchFinishDTO: Codable {
    let is_user_best: Bool
    let is_track_best: Bool
    let rewards: [CCRewardResponse]
    let xp_before: Int      // 原 XP
    let xp_delta: Int       // 变化的 XP
}

struct MatchFinishResponse: Codable {
    let match_result: MatchFinishDTO?
}

struct BikeFinishFreeTrainingRequest: Codable {
    let start_time: String
    let end_time: String
    let path: [BikeFreeTrainingPathPoint]
    let client_upload_id: String        // 客户端生成的幂等键，供服务端去重
}

struct RunningFinishFreeTrainingRequest: Codable {
    let start_time: String
    let end_time: String
    let path: [RunningFreeTrainingPathPoint]
    let client_upload_id: String        // 客户端生成的幂等键，供服务端去重
}

struct FreeTrainingFinishResponse: Codable {
    let record_id: String
    let xp_before: Int
    let xp_delta: Int
    let training_state_before: Int
    let training_state_delta: Int
    let new_grids: Int
    let triggered_buff_count: Int
    let cc_rewards: [CCRewardResponse]
}

struct BikeFinishRouteTrainingRequest: Codable {
    let route_id: String
    let start_time: String
    let end_time: String
    let path: [BikeRouteTrainingPathPoint]
    let bonus_in_cards: [CardBonusItem]
    let client_upload_id: String        // 客户端生成的幂等键，供服务端去重
}

struct RunningFinishRouteTrainingRequest: Codable {
    let route_id: String
    let start_time: String
    let end_time: String
    let path: [RunningRouteTrainingPathPoint]
    let bonus_in_cards: [CardBonusItem]
    let client_upload_id: String        // 客户端生成的幂等键，供服务端去重
}

struct RouteTrainingFinishResponse: Codable {
    let record_id: String
    let xp_before: Int
    let xp_delta: Int
    let training_state_before: Int
    let training_state_delta: Int
    let new_grids: Int
    let cc_rewards: [CCRewardResponse]
}


// todo: 拆分不同运动的统计数据
struct StatisticData {
    var distance: Double = 0        // 距离/m
    var avgSpeed: Double = 0        // 平均速度km/h
    var elevationGain: Double = 0   // 累计爬升/m
    var heartRate: Int? = nil         // 心率
    var totalEnergy: Int? = nil        // 能耗
    var pedalCadence: Int? = nil       // 踏频
    var stepCadence: Int? = nil        // 步频
    var power: Int? = nil              // 功率
    
    static let empty = StatisticData()
}

class IMUFilter {
    // 简单一阶低通滤波
    private var previousFilteredValue: Double = 0.0
    private let alpha: Double = 0.1     // 0<alpha<1, alpha 越小 抑制越强
    // 简单高通滤波（用于移除重力／慢摆动成分）
    private var previousInput: Double = 0.0
    private var previousHighPassOutput: Double = 0.0
    private let highPassCutoff: Double  // 单位 Hz
    private let sampleRate: Double      // Hz
    
    init(highPassCutoff: Double, sampleRate: Double) {
        self.highPassCutoff = highPassCutoff
        self.sampleRate = sampleRate
    }
    
    func lowPass(current: Double) -> Double {
        let filtered = alpha * current + (1.0 - alpha) * previousFilteredValue
        previousFilteredValue = filtered
        return filtered
    }
    
    func highPass(current: Double) -> Double {
        let rc = 1.0 / (2.0 * Double.pi * highPassCutoff)
        let dt = 1.0 / sampleRate
        let alphaHP = rc / (rc + dt)
        let filtered = alphaHP * (previousHighPassOutput + current - previousInput)
        previousInput = current
        previousHighPassOutput = filtered
        return filtered
    }

    // 数据处理，先高通移除重力，再低通平滑
    func filteredSamples(x: Double, y: Double, z: Double) -> Double {
        // 1) 计算模值（向量长度）
        let raw = sqrt(x * x + y * y + z * z)
        // 2) remove gravity / slow drift
        let hp = highPass(current: raw)
        // 3) smooth
        let lp = lowPass(current: hp)
        return lp
    }
}

// phone端完整数据格式
struct PhoneData {
    let timestamp: TimeInterval
    let altitude: CLLocationDistance
    let speed: CLLocationSpeed
    let accX: Double
    let accY: Double
    let accZ: Double
    let gyroX: Double
    let gyroY: Double
    let gyroZ: Double
    let magX: Double
    let magY: Double
    let magZ: Double
    let audioSample: Bool // 简化为布尔值，表示是否有音频数据
    
    init() {
        timestamp = 0
        altitude = 0
        speed = 0
        accX = 0
        accY = 0
        accZ = 0
        gyroX = 0
        gyroY = 0
        gyroZ = 0
        magX = 0
        magY = 0
        magZ = 0
        audioSample = false
    }
    
    init(timestamp: TimeInterval, altitude: CLLocationDistance, speed: CLLocationSpeed, accX: Double, accY: Double, accZ: Double, gyroX: Double, gyroY: Double, gyroZ: Double, magX: Double, magY: Double, magZ: Double, audioSample: Bool) {
        self.timestamp = timestamp
        self.altitude = altitude
        self.speed = speed
        self.accX = accX
        self.accY = accY
        self.accZ = accZ
        self.gyroX = gyroX
        self.gyroY = gyroY
        self.gyroZ = gyroZ
        self.magX = magX
        self.magY = magY
        self.magZ = magZ
        self.audioSample = audioSample
    }
}

// 传感器数据格式（ watch端/phone端 ）
struct SensorData {
    let timestamp: TimeInterval
    let accX: Double
    let accY: Double
    let accZ: Double
    let gyroX: Double
    let gyroY: Double
    let gyroZ: Double
    //let magX: Double
    //let magY: Double
    //let magZ: Double
    
    init() {
        timestamp = 0
        accX = 0
        accY = 0
        accZ = 0
        gyroX = 0
        gyroY = 0
        gyroZ = 0
        //magX = 0
        //magY = 0
        //magZ = 0
    }
    
    init(timestamp: TimeInterval, accX: Double, accY: Double, accZ: Double, gyroX: Double, gyroY: Double, gyroZ: Double/*, magX: Double, magY: Double, magZ: Double*/) {
        self.timestamp = timestamp
        self.accX = accX
        self.accY = accY
        self.accZ = accZ
        self.gyroX = gyroX
        self.gyroY = gyroY
        self.gyroZ = gyroZ
        //self.magX = magX
        //self.magY = magY
        //self.magZ = magZ
    }
}

// 用于预测的传感器数据格式
struct SensorTrainingData {
    let accX: Double
    let accY: Double
    let accZ: Double
    let gyroX: Double
    let gyroY: Double
    let gyroZ: Double
    //let magX: Double
    //let magY: Double
    //let magZ: Double
    
    init() {
        accX = 0
        accY = 0
        accZ = 0
        gyroX = 0
        gyroY = 0
        gyroZ = 0
        //magX = 0
        //magY = 0
        //magZ = 0
    }
    
    init(accX: Double, accY: Double, accZ: Double, gyroX: Double, gyroY: Double, gyroZ: Double/*, magX: Double, magY: Double, magZ: Double*/) {
        self.accX = accX
        self.accY = accY
        self.accZ = accZ
        self.gyroX = gyroX
        self.gyroY = gyroY
        self.gyroZ = gyroZ
        //self.magX = magX
        //self.magY = magY
        //self.magZ = magZ
    }
}
