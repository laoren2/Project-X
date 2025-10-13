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


// phone数据保存到本地
let SAVEPHONEDATA: Bool = {
    #if DEBUG
    return false
    #else
    return false
    #endif
}()

// sensor数据保存到本地
let SAVESENSORDATA: Bool = {
    #if DEBUG
    return false
    #else
    return false
    #endif
}()

// 是否跳过比赛数据校验
let SKIPMATCHVERIFY: Bool = {
    #if DEBUG
    return true
    #else
    return false
    #endif
}()

class CompetitionManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = CompetitionManager()
    
    let navigationManager = NavigationManager.shared
    let dataFusionManager = DataFusionManager.shared
    let modelManager = ModelManager.shared
    let deviceManager = DeviceManager.shared
    let user = UserManager.shared
    let globalConfig = GlobalConfig.shared
    
    let eventBus = MatchEventBus()      // 比赛引擎的总线，负责比赛中事件的注册和通知
    let matchContext = MatchContext()   // 比赛进行中的上下文信息
    
    // 当前进行中的运动和记录
    var sport: SportName = .Default
    var currentBikeRecord: BikeRaceRecord?
    var currentRunningRecord: RunningRaceRecord?
    var isTeam: Bool {
        switch sport {
        case .Bike:
            return currentBikeRecord?.isTeam == true
        case .Running:
            return currentRunningRecord?.isTeam == true
        default:
            return false
        }
    }
    
    @Published var selectedCards: [MagicCard] = []
    var activeCardEffects: [MagicCardEffect] = []
    // | 00   +   +   +   +   +    +  |
    //        |   |   |   |   |    |
    //       WST  RF  LF  RH  LH  PHONE
    var sensorRequest: Int = 0
    @Published var isEffectsFinishPrepare = true        // 所有cardeffects是否完成准备工作
    //var expectedStatsWatchCount: Int = 0              // 需要等待接收最后统计数据的外设个数
    
    @Published var isRecording: Bool = false // 当前比赛状态
    @Published var isShowWidget: Bool = false // 是否显示Widget
    
    @Published var showAlert = false // 是否弹出提示
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    @Published var userLocation: CLLocationCoordinate2D? = nil // 当前用户位置
    @Published var isInValidArea: Bool = false // 是否在比赛出发点
    
    @Published var startCoordinate = CLLocationCoordinate2D(latitude: 31.00550, longitude: 121.40962)
    @Published var endCoordinate = CLLocationCoordinate2D(latitude: 31.03902, longitude: 121.39807)
    
    let safetyRadius: CLLocationDistance = 50.0
    
    private var motionManager: CMMotionManager = CMMotionManager()
    private var audioRecorder: AVAudioRecorder!
    private var startTime: Date?
    
    // 仅用于保存传感器数据到本地调试
    private var competitionData: [PhoneData] = []
    private let batchSize = 60 // 每次采集60条数据后写入文件
    
    private var pathData: [PathPoint] = []
    
    private var timer: DispatchSourceTimer? //定时器
    private var collectionTimer: Timer?

    private var teamJoinTimerA: Timer? // 用于获取比赛剩余可加入时间的计时器
    private var teamJoinTimerB: Timer? // 用于剩余可加入时间倒计时的计时器
    var teamJoinTimeWindow: Int = 180 // 组队模式下的可加入时间窗口
    
    // todo: 将频繁更新的属性移出competitionManager，否则会影响某些系统ui交互（如alert button）
    @Published var teamJoinRemainingTime: Int = 180 // 剩余可加入时间，频繁更新，暂时无交互受影响，先放在这里
    @Published var isTeamJoinWindowExpired: Bool = false // 是否已过期

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
        var recordID: String? = nil
        if sport == .Bike {
            recordID = currentBikeRecord?.record_id
        } else if sport == .Running {
            recordID = currentRunningRecord?.record_id
        } else {
            return
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
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    DispatchQueue.main.async {
                        if let expired_date = unwrappedData.expired_date, let expired = formatter.date(from: expired_date) {
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
    private var locationSelectedViewCancellable: AnyCancellable?
    private var locationDetailViewCancellable: AnyCancellable?
    private var dataCancellables = Set<AnyCancellable>()


    private override init() {
        super.init()
        
        motionManager.accelerometerUpdateInterval = 0.05
        motionManager.gyroUpdateInterval = 0.05
        motionManager.magnetometerUpdateInterval = 0.05
        //requestMicrophoneAccess()
        setupDataBindings()
        // 嵌套的ObservableObject逐层订阅通知写在这里：
    }
    
    // 设置 Combine 订阅
    func setupRealtimeViewLocationSubscription() {
        // 订阅位置更新
        locationSelectedViewCancellable = LocationManager.shared.locationPublisher()
            .subscribe(on: DispatchQueue.global(qos: .background)) // 在后台处理数据发送
            .receive(on: DispatchQueue.main) // 主线程更新UI或快速响应
            .sink { location in
                self.handleLocationUpdate(location)
            }
    }
    
    func deleteRealtimeViewLocationSubscription() {
        locationSelectedViewCancellable?.cancel()
    }
    
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
    
    // 收到通知的回调
    private func handleLocationUpdate(_ location: CLLocation) {
        // 在这里处理位置更新，比如后台计算、数据存储或UI响应
        // 已经在主线程上，将耗时操作转入后台
        //userLocation = location.coordinate
        DispatchQueue.global(qos: .background).async { [self] in
            if isRecording {
                // 比赛进行中，检查用户是否在终点的安全区域内
                let dis = location.distance(from: CLLocation(latitude: endCoordinate.latitude, longitude: endCoordinate.longitude))
                let inEndZone = dis <= safetyRadius
                //print("是否到达终点: ",inEndZone,"距离: \(dis) ")
                if inEndZone {
                    DispatchQueue.main.async {
                        self.stopCompetition()
                    }
                }
            } else {
                // 比赛开始前，检查用户是否在出发点的安全区域内
                let distance = location.distance(from: CLLocation(latitude: startCoordinate.latitude, longitude: startCoordinate.longitude))
                DispatchQueue.main.async {
                    self.isInValidArea = distance <= self.safetyRadius
                }
            }
        }
    }
    
    // Request microphone access
    /*private func requestMicrophoneAccess() {
        AVAudioApplication.requestRecordPermission(completionHandler: { [weak self] granted in
            if granted {
                self?.setupAudioRecorder()
            } else {
                Logger.competition.notice_public("Microphone access denied.")
            }
        })
    }*/
    
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
            alertTitle = "无法开始比赛"
            alertMessage = "需要后台定位权限，请将定位权限调整为始终允许以进行持续的比赛记录。"
            showAlert = true
            return
        }
        // 检查麦克风权限
        //switch AVAudioApplication.shared.recordPermission {
        //case .granted:
            // 权限已授予，开始比赛
            Task {
                let result = await startCompetition_server()
                await MainActor.run {
                    if result {
                        globalConfig.refreshRecordManageView = true
                        startRecordingSession()
                    } else {
                        return
                    }
                }
            }
        /*case .denied:
            // 提示权限被拒绝
            alertTitle = "无法开始比赛"
            alertMessage = "请先打开麦克风权限以进行比赛记录。"
            showAlert = true
        case .undetermined:
            // 权限状态未确定，重新请求
            requestMicrophoneAccess()
        @unknown default:
            // 提示未知情况
            alertTitle = "无法开始比赛"
            alertMessage = "麦克风状态错误，请检查麦克风权限。"
            showAlert = true
        }*/
    }
    
    func stopCompetition() {
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
        finalizeCompetition()
    }
    
    // 处理外设发送来的统计数据
    func handleStatsData(stats: [String: Any]) {
        statsQueue.async {
            if let avgHeartRate = stats["avgHeartRate"] as? Double {
                self.matchContext.avgHeartRate = avgHeartRate
            }
            if let totalEnergy = stats["totalEnergy"] as? Double {
                self.matchContext.totalEnergy = totalEnergy
            }
            if let avgPower = stats["avgPower"] as? Double {
                self.matchContext.avgPower = avgPower
            }
            if let latestHeartRate = stats["latestHeartRate"] as? Double {
                self.matchContext.latestHeartRate = latestHeartRate
            }
            if let latestPower = stats["latestPower"] as? Double {
                self.matchContext.latestPower = latestPower
            }
        }
    }
    
    func finalizeCompetition() {
        if SAVEPHONEDATA {
            self.finalizeCompetitionData()
        }
        eventBus.emit(.matchEnd, context: matchContext)
        
        finishCompetition_server()
        
        resetCompetitionProperties()
        Logger.competition.notice_public("competition stop")
    }
    
    // todo: 使用机器学习模型校验
    func verifyBikeMatchData() -> Bool {
        guard startTime != nil else { return false }
        guard let lastPointLat = pathData.last?.lat,
              let lastPointLon = pathData.last?.lon,
              let startTime = pathData.first?.timestamp,
              let endTime = pathData.last?.timestamp,
              startTime < endTime else {
            return false
        }
        let location = CLLocation(latitude: lastPointLat, longitude: lastPointLon)
        let dis = location.distance(from: CLLocation(latitude: endCoordinate.latitude, longitude: endCoordinate.longitude))
        guard dis <= safetyRadius else { return false }
        
        guard pathData.count >= 2 else {
            // 路径过短，不能校验，默认不合法
            return false
        }
        
        // 总分数为100
        var score = 100
        
        let totalTime = endTime - startTime  // 秒
        let totalMeters = computeTotalDistance(path: pathData)
        let avgSpeedKmh = (totalMeters / totalTime) * 3.6  // 转 km/h
        
        // 规则 1：平均速度太低 → 不进行深度校验（直接视为合法）
        if avgSpeedKmh < 20 {
            return true
        }
        
        // 规则 2：局部速度极端段
        let segSpeeds = computeSegmentSpeeds(path: pathData, windowMeters: 100)
        for v in segSpeeds {
            if v > 80 {
                // 极端超速段
                score -= 20
            } else if v > 60 {
                score -= 10
            } else if v > 50 {
                score -= 5
            }
        }
        
        // 规则 3：海拔跳跃异常
        let altitudes = pathData.map { $0.altitude }
        if detectElevationJump(elevs: altitudes, maxJump: 50.0) {
            score -= 10
        }
        
        // 规则 4：坡度极端
        let slopeStats = computeSlopeStats(path: pathData)
        if slopeStats.maxSlope > 1.0 {
            // 最大坡度 > 100% 非现实
            score -= 10
        } else if slopeStats.maxSlope > 0.7 {
            score -= 5
        }
        
        // 规则 5：GPS 跳变数
        let jumpCount = countGpsJumps(path: pathData, maxReasonableKmh: 50)
        score -= jumpCount * 5
        
        // 规则 6：功率 / 心率 一致性（如果有）
        //if let avgPower = matchContext.avgPower {
            // 假设你有功率数据
            // 这里用示例 isPowerConsistent
            // if !isPowerConsistent(speed: avgSpeedKmh, power: avgPower) {
            //     score -= 10
            // }
        //}
        
        // 规则 7: 上坡时的速度 & 心率变化
        
        // 限制最低分数
        if score < 0 { score = 0 }
        
        // 根据最终 score 决定验证结果
        // 可以定义不同分数区间：
        // ≥ 80 : 合法
        // 60–80 : 可疑（可能人工复核）
        // < 60 : 拒绝 / 判定为作弊
        
        if score >= 80 {
            return true  // 合法
        } else if score >= 60 {
            // 可疑：你可以考虑半通过 / 标记给后台 / 或者人工审核
            return true  // 也可以返回 false / 标记可疑
        } else {
            // 严重异常
            return false
        }
    }
    
    func verifyRunningMatchData() -> Bool {
        guard startTime != nil else { return false }
        guard let lastPointLat = pathData.last?.lat,
              let lastPointLon = pathData.last?.lon,
              let startTime = pathData.first?.timestamp,
              let endTime = pathData.last?.timestamp,
              startTime < endTime else {
            return false
        }
        let location = CLLocation(latitude: lastPointLat, longitude: lastPointLon)
        let dis = location.distance(from: CLLocation(latitude: endCoordinate.latitude, longitude: endCoordinate.longitude))
        guard dis <= safetyRadius else { return false }
        
        guard pathData.count >= 2 else {
            // 路径过短，不能校验，默认不合法
            return false
        }
        
        // 总分数为100
        var score = 100
        
        let totalTime = endTime - startTime  // 秒
        let totalMeters = computeTotalDistance(path: pathData)
        let avgSpeedKmh = (totalMeters / totalTime) * 3.6  // 转 km/h
        
        // 规则 1：平均速度太低 → 不进行深度校验（直接视为合法）
        if avgSpeedKmh < 10 {
            return true
        }
        // 规则 2：局部速度极端段
        let segSpeeds = computeSegmentSpeeds(path: pathData, windowMeters: 100)
        for v in segSpeeds {
            if v > 30 {
                score -= 20
            } else if v > 25 {
                score -= 10
            } else if v > 20 {
                score -= 5
            }
        }
        
        // 规则 3：海拔跳跃异常
        let altitudes = pathData.map { $0.altitude }
        if detectElevationJump(elevs: altitudes, maxJump: 50.0) {
            score -= 10
        }
        
        // 规则 4：坡度极端
        let slopeStats = computeSlopeStats(path: pathData)
        if slopeStats.maxSlope > 2 {
            // 最大坡度 > 100% 非现实
            score -= 10
        } else if slopeStats.maxSlope > 1 {
            score -= 5
        }
        
        // 规则 5：GPS 跳变数
        let jumpCount = countGpsJumps(path: pathData, maxReasonableKmh: 30)
        score -= jumpCount * 5
        
        // 规则 6：功率 / 心率 一致性（如果有）
        //if let avgPower = matchContext.avgPower {
            // 假设你有功率数据
            // 这里用示例 isPowerConsistent
            // if !isPowerConsistent(speed: avgSpeedKmh, power: avgPower) {
            //     score -= 10
            // }
        //}
        
        // 规则 7: 上坡时的速度 & 心率变化
        
        // 限制最低分数
        if score < 0 { score = 0 }
        
        if score >= 80 {
            return true  // 合法
        } else if score >= 60 {
            return true
        } else {
            // 严重异常
            return false
        }
    }
    
    func organizeEndTime() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let endTime = formatter.string(from: Date())
        return endTime
    }
    
    // todo: 暂时开始时间和结束时间都由客户端决定，未来可在服务端接收到请求后记录时间进行二次验证
    func finishCompetition_server() {
        
        // 校验 & 整理轨迹和时间
        let optimizeEndTime = organizeEndTime()
        
        if let record = currentBikeRecord, sport == .Bike {
            var validationResult = verifyBikeMatchData()
            if SKIPMATCHVERIFY {
                validationResult = true
            }
            //print("BikeMatchData verify result: \(validationResult)")
            var headers: [String: String] = [:]
            headers["Content-Type"] = "application/json"
            let requestData = FinishMatchRequest(
                validation_status: validationResult,
                record_id: record.record_id,
                end_time: optimizeEndTime,
                bonus_in_cards: matchContext.bonusEachCards,
                path: pathData
            )
            guard let encodedBody = try? JSONEncoder().encode(requestData) else {
                return
            }
            
            let request = APIRequest(path: "/competition/bike/finish_\(record.isTeam ? "team" : "single")_competition", method: .post, headers: headers, body: encodedBody, requiresAuth: true)
            NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
                switch result {
                case .success:
                    self.globalConfig.refreshRecordManageView = true
                    self.globalConfig.refreshTeamManageView = true
                    DispatchQueue.main.async {
                        self.navigationManager.append(.bikeRecordDetailView(recordID: record.record_id, userID: self.user.user.userID))
                    }
                default: break
                }
            }
        }
        if let record = currentRunningRecord, sport == .Running {
            var validationResult = verifyRunningMatchData()
            if SKIPMATCHVERIFY {
                validationResult = true
            }
            //print("RunningMatchData verify result: \(validationResult)")
            var headers: [String: String] = [:]
            headers["Content-Type"] = "application/json"
            let requestData = FinishMatchRequest(
                validation_status: validationResult,
                record_id: record.record_id,
                end_time: optimizeEndTime,
                bonus_in_cards: matchContext.bonusEachCards,
                path: pathData
            )
            guard let encodedBody = try? JSONEncoder().encode(requestData) else {
                return
            }
            
            let request = APIRequest(path: "/competition/running/finish_\(record.isTeam ? "team" : "single")_competition", method: .post, headers: headers, body: encodedBody, requiresAuth: true)
            NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
                switch result {
                case .success:
                    self.globalConfig.refreshRecordManageView = true
                    self.globalConfig.refreshTeamManageView = true
                    DispatchQueue.main.async {
                        self.navigationManager.append(.runningRecordDetailView(recordID: record.record_id, userID: self.user.user.userID))
                    }
                default: break
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
            let result = await NetworkService.sendAsyncRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true)
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
            let result = await NetworkService.sendAsyncRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true)
            switch result {
            case .success:
                return true
            case .failure:
                return false
            }
        }
        let toast = Toast(message: "暂不支持此运动")
        ToastManager.shared.show(toast: toast)
        return false
    }
    
    func startRecordingSession() {
        matchContext.reset()
        matchContext.isTeam = isTeam
        // 默认将所有加载卡牌添加进 matchContext 中
        for card in activeCardEffects {
            matchContext.addOrUpdateBonus(cardID: card.cardID, bonus: 0)
        }
        eventBus.emit(.matchStart, context: matchContext)
        
        // 重置组队模式下的计时环境
        stopAllTeamJoinTimers()
        teamJoinRemainingTime = teamJoinTimeWindow
        isTeamJoinWindowExpired = false
        
        isRecording = true
        competitionData = []
        
        // Start location updates
        LocationManager.shared.changeToHighUpdate()
        setupCompetitionLocationSubscription()
        deleteRealtimeViewLocationSubscription()

        // Start accelerometer/gyro/magnet updates
        motionManager.startAccelerometerUpdates()
        motionManager.startGyroUpdates()
        motionManager.startMagnetometerUpdates()
        
        // 开始音频录制
        //startRecordingAudio()
        
        // 使用定时器每0.05秒记录一次数据
        self.startTimer()
        
        let isNeedPhoneData = sensorRequest & 0b000001 != 0
        let sensorRequest = sensorRequest >> 1
        //dataFusionManager.setPredictWindow(maxWindow: modelManager.maxInputWindow)
        
        // 所有设备开始收集数据
        if isNeedPhoneData {
            dataFusionManager.deviceNeedToWork |= 0b000001
        }
        for (pos, dev) in deviceManager.deviceMap {
            if let device = dev, (sensorRequest & (1 << pos.rawValue)) != 0 {
                dataFusionManager.deviceNeedToWork |= (1 << (pos.rawValue + 1))
                //startCollecting(device: device)
                Logger.competition.notice_public("\(pos.name) watch data start collecting")
                device.startCollection(activityType: sport, locationType: "outdoor")  // 开始数据收集
            }
        }
    }
    
    // 启动定时器
    private func startTimer() {
        // 在比赛开始时已记录下 startTime = Date()
        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now(), repeating: 0.05) // 每0.05秒触发一次
        var tickCounter = 0 // 用于计数，每次事件触发加1
        
        timer.setEventHandler { [weak self] in
            guard let self = self, self.isRecording, let start = self.startTime else { return }
            
            // 记录 phone 端数据
            if self.sensorRequest & 0b000001 != 0 {
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
            if tickCounter % 60 == 0 { // 60 * 0.05s = 3s
                self.recordPath()
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
        collectionTimer?.invalidate()
        collectionTimer = nil
        timer?.cancel()
        timer = nil
        recordPath()
        Logger.competition.notice_public("stop phone timer.")
    }
    
    // 记录path数据
    private func recordPath() {
        guard let location = LocationManager.shared.getLocation() else {
            print("location data missed in path point.")
            return
        }
        let altitude = LocationManager.shared.getLocation()?.altitude ?? -11034
        let speed = LocationManager.shared.getLocation()?.speed ?? -1
        let pathPoint = PathPoint(
            lat: location.coordinate.latitude,
            lon: location.coordinate.longitude,
            speed: speed,
            altitude: altitude,
            timestamp: location.timestamp.timeIntervalSince1970
        )
        pathData.append(pathPoint)
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
        let zone = NSTimeZone.system
        let timeInterval = zone.secondsFromGMT()
        let dateNow = Date().addingTimeInterval(TimeInterval(timeInterval))
        
        let dataPoint = PhoneData(
            timestamp: dateNow,
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
        
        if SAVEPHONEDATA {
            competitionData.append(dataPoint)
            // 检查是否达到批量保存条件
            if competitionData.count >= batchSize {
                let batch = competitionData
                competitionData.removeAll()
                saveBatchAsCSV(dataBatch: batch)
            }
        }
    }
    
    // 保存批次数据为CSV
    private func saveBatchAsCSV(dataBatch: [PhoneData]) {
        // 定义CSV文件路径
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent("competitionData_phone.csv")
        
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
        let dateFormatter = ISO8601DateFormatter()
        
        for data in dataBatch {
            let timestamp = dateFormatter.string(from: data.timestamp)
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
    
    private func startRecordingAudio() {
        // Optional: Setup audio recording if needed
    }
    
    private func stopRecordingAudio() {
        // Optional: Stop audio recording and save the sample
    }
    
    // 设置运动和记录，准备开始比赛
    func resetBikeRaceRecord(record: BikeRaceRecord) {
        sport = .Bike
        currentBikeRecord = record
        startCoordinate = record.trackStart
        endCoordinate = record.trackEnd
    }
    
    func resetRunningRaceRecord(record: RunningRaceRecord) {
        sport = .Running
        currentRunningRecord = record
        startCoordinate = record.trackStart
        endCoordinate = record.trackEnd
    }
    
    func activateCards(_ cards: [MagicCard]) {
        isEffectsFinishPrepare = false
        guard cards.count <= 3 else {
            ToastManager.shared.show(toast: Toast(message: "最多选择3张卡牌"))
            return
        }
        
        // 卸载所有effects
        sensorRequest = 0
        dataFusionManager.resetAll()
        
        selectedCards = cards
        activeCardEffects = selectedCards.map { card in
            MagicCardFactory.createEffect(level: card.level, from: card.cardDef)
        }
        eventBus.reset()
        Task {
            var allPrepared = true
            for effect in activeCardEffects {
                effect.register(eventBus: eventBus)
                let prepared = await effect.load()
                if !prepared {
                    allPrepared = false
                }
            }
            let isAllPrepared = allPrepared
            await MainActor.run {
                isEffectsFinishPrepare = isAllPrepared
            }
        }
    }
    
    func resetCompetitionProperties() {
        dataFusionManager.resetAll()
        
        teamJoinRemainingTime = teamJoinTimeWindow
        isTeamJoinWindowExpired = false
        currentBikeRecord = nil
        currentRunningRecord = nil
        selectedCards.removeAll()
        activeCardEffects.removeAll()
        eventBus.reset()
        matchContext.reset()
        sensorRequest = 0
        startCoordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        endCoordinate = CLLocationCoordinate2D(latitude: 1, longitude: 1)
        startTime = nil
        sport = .Default
        pathData = []
        //expectedStatsWatchCount = 0
        
        isInValidArea = false
        isEffectsFinishPrepare = true
    }
}

extension CompetitionManager {
    // 计算两点之间的地面水平距离（忽略高度差），单位 m
    func horizontalDistance(from p1: PathPoint, to p2: PathPoint) -> Double {
        let loc1 = CLLocation(latitude: p1.lat, longitude: p1.lon)
        let loc2 = CLLocation(latitude: p2.lat, longitude: p2.lon)
        return loc1.distance(from: loc2)
    }
    
    // 计算路径的总水平距离（累计每段水平距离），单位 m
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
            
            let dt = p2.timestamp - p1.timestamp
            var dist = horizontalDistance(from: p1, to: p2)
            
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
    var isTeam: Bool
    var latestHeartRate: Double
    var latestPower: Double
    var avgHeartRate: Double
    var totalEnergy: Double
    var avgPower: Double
    var sensorData: DataSnapshot
    var bonusEachCards: [CardBonusItem]
    
    init() {
        self.isTeam = false
        self.latestHeartRate = 0
        self.latestPower = 0
        self.avgHeartRate = 0
        self.totalEnergy = 0
        self.avgPower = 0
        self.sensorData = DataSnapshot(phoneSlice: [], sensorSlice: [], predictTime: 0)
        self.bonusEachCards = []
    }
    
    func reset() {
        isTeam = false
        latestHeartRate = 0
        latestPower = 0
        avgHeartRate = 0
        totalEnergy = 0
        avgPower = 0
        sensorData = DataSnapshot(phoneSlice: [], sensorSlice: [], predictTime: 0)
        bonusEachCards = []
    }
    
    func addOrUpdateBonus(cardID: String, bonus: Double) {
        if let idx = bonusEachCards.firstIndex(where: { $0.card_id == cardID }) {
            bonusEachCards[idx].bonus_time += bonus
        } else {
            bonusEachCards.append(CardBonusItem(card_id: cardID, bonus_time: bonus))
        }
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
    let timestamp: TimeInterval
}

struct CardBonusItem: Codable {
    let card_id: String
    var bonus_time: Double
}

struct FinishMatchRequest: Codable {
    let validation_status: Bool
    let record_id: String
    let end_time: String
    let bonus_in_cards: [CardBonusItem]
    let path: [PathPoint]
}

// phone端完整数据格式
struct PhoneData {
    let timestamp: Date
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
        timestamp = .now
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
    
    init(timestamp: Date, altitude: CLLocationDistance, speed: CLLocationSpeed, accX: Double, accY: Double, accZ: Double, gyroX: Double, gyroY: Double, gyroZ: Double, magX: Double, magY: Double, magZ: Double, audioSample: Bool) {
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

// todo
struct PhoneTrainingData {}

// 传感器数据格式（ watch端/phone端 ）
struct SensorData {
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
    
    init() {
        timestamp = .now
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
    
    init(timestamp: Date, accX: Double, accY: Double, accZ: Double, gyroX: Double, gyroY: Double, gyroZ: Double/*, magX: Double, magY: Double, magZ: Double*/) {
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
