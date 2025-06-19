//
//  CompetitionManager.swift
//  sportsx
//
//  一个巨大的状态机，管理和控制一场比赛的全过程
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
let SAVEPHONEDATA = false // phone数据保存到本地
let SAVESENSORDATA = false // sensor数据保存到本地
#endif


class CompetitionManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = CompetitionManager()
    
    let dataFusionManager = DataFusionManager.shared
    let modelManager = ModelManager.shared
    let deviceManager = DeviceManager.shared
    let user = UserManager.shared
    
    var currentCompetitionRecord: CompetitionRecord? // = CompetitionRecord()
    
    // 仅用于本地测试
    var competitionRecords: [CompetitionRecord] = []
    
    // 仅用于本地测试
    @Published var myCreatedTeams: [Team] = []
    @Published var myJoinedTeams: [Team] = []
    @Published var myAppliedTeams: [Team] = []
    @Published var availableTeams: [Team] = []
    
    @Published var selectedCards: [MagicCard] = []
    var sensorRequest: Int = 0
    
    @Published var predictResultCnt: Int = 0
    
    @Published var isRecording: Bool = false // 当前比赛状态
    @Published var isShowWidget: Bool = false // 是否显示Widget
    
    @Published var showAlert = false // 是否弹出提示
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    @Published var userLocation: CLLocationCoordinate2D? = nil // 当前用户位置
    @Published var canStartCompetition: Bool = false // 是否可以开始比赛
    
    @Published var compensationTime: Double = 0 // 通过MagicCard拿到的总补偿时间
    @Published var modelResults: [String: Any] = [:] // 存储每个模型的预测结果
    
    @Published var startCoordinate = CLLocationCoordinate2D(latitude: 31.00550, longitude: 121.40962)
    @Published var endCoordinate = CLLocationCoordinate2D(latitude: 31.03902, longitude: 121.39807)
    
    let safetyRadius: CLLocationDistance = 50.0
    
    private var motionManager: CMMotionManager = CMMotionManager()
    private var audioRecorder: AVAudioRecorder!
    private var startTime: Date?
    
    // 仅用于保存传感器数据到本地调试
    private var competitionData: [PhoneData] = []
    private let batchSize = 60 // 每次采集60条数据后写入文件
    
    private var timer: DispatchSourceTimer? //定时器
    private var collectionTimer: Timer?

    private var teamJoinTimerA: Timer? // 用于获取比赛剩余可加入时间的计时器
    private var teamJoinTimerB: Timer? // 用于剩余可加入时间倒计时的计时器
    var teamJoinTimeWindow: Int = 30 // 组队模式下的可加入时间窗口
    
    // todo: 将频繁更新的属性移出competitionManager
    @Published var teamJoinRemainingTime: Int = 30 // 剩余可加入时间，频繁更新，暂时无交互受影响，先放在这里
    @Published var isTeamJoinWindowExpired: Bool = false // 是否已过期

    // 计时器a和计时器b
    func startTeamJoinTimerA() {
        if teamJoinTimerA == nil {
            teamJoinTimerA = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self, let teamCode = self.currentCompetitionRecord?.teamCode else { return }
                
                if let timestamp = self.getTeamTimestampInSeconds(teamCode: teamCode) {
                    // 找到比赛时间，切换到计时器b
                    self.teamJoinRemainingTime = max(0, self.teamJoinTimeWindow - timestamp)
                    self.startTeamJoinTimerB()
                    self.stopTeamJoinTimerA()
                }
            }
        }
    }
    
    func stopTeamJoinTimerA() {
        teamJoinTimerA?.invalidate()
        teamJoinTimerA = nil
    }
    
    func startTeamJoinTimerB() {
        if teamJoinTimerB == nil {
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
    }
    
    func stopAllTeamJoinTimers() {
        stopTeamJoinTimerA()
        stopTeamJoinTimerB()
    }

    private let dataHandleQueue = DispatchQueue(label: "com.sportsx.competition.dataHandleQueue", qos: .userInitiated) // 串行队列，用于处理数据
    private let timerQueue = DispatchQueue(label: "com.sportsx.competition.timerQueue", qos: .userInitiated) // 串行队列，用于处理手机端高频计时器的回调
    private var modelRemainingSamples: [String: Int] = [:] // 记录每个模型的剩余预测条数
    
    // Combine
    private var locationSelectedViewCancellable: AnyCancellable?
    private var locationDetailViewCancellable: AnyCancellable?
    private var dataCancellables = Set<AnyCancellable>()


    private override init() {
        super.init()
        // 本地测试
        availableTeams = generateDummyAvailableTeams(eventId: 0, trackId: 0)
        myJoinedTeams = generateDummyJoinedTeams()
        
        motionManager.accelerometerUpdateInterval = 0.05
        motionManager.gyroUpdateInterval = 0.05
        motionManager.magnetometerUpdateInterval = 0.05
        requestMicrophoneAccess()
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
                Logger.competition.notice_public("predict time: \(snapshot.predictTime)")
                self?.checkModelsForPrediction(with: snapshot)
            }
            .store(in: &dataCancellables)
    }
    
    // 收到通知的回调
    private func handleLocationUpdate(_ location: CLLocation) {
        // 在这里处理位置更新，比如后台计算、数据存储或UI响应
        // 已经在主线程上，将耗时操作转入后台
        //userLocation = location.coordinate
        DispatchQueue.global(qos: .background).async { [self] in
            let startCoordinate_WGS = CoordinateConverter.gcj02ToWgs84(lat: startCoordinate.latitude, lon: startCoordinate.longitude)
            let endCoordinate_WGS = CoordinateConverter.gcj02ToWgs84(lat: endCoordinate.latitude, lon: endCoordinate.longitude)
            if isRecording {
                // 比赛进行中，检查用户是否在终点的安全区域内
                let dis = location.distance(from: CLLocation(latitude: endCoordinate_WGS.latitude, longitude: endCoordinate_WGS.longitude))
                let inEndZone = dis <= safetyRadius
                //print("是否到达终点: ",inEndZone,"距离: \(dis) ")
                if inEndZone {
                    DispatchQueue.main.async {
                        self.stopCompetition()
                    }
                }
            } else {
                // 比赛开始前，检查用户是否在出发点的安全区域内
                let distance = location.distance(from: CLLocation(latitude: startCoordinate_WGS.latitude, longitude: startCoordinate_WGS.longitude))
                
                DispatchQueue.main.async {
                    self.canStartCompetition = distance <= self.safetyRadius
                }
            }
        }
    }
    
    /*private func handleModelPrediction(modelName: String, result: Any) {
        // 根据模型名称和结果类型进行处理
        print("模型 \(modelName) 预测结果: \(result)")
        // 这里可以根据需要更新UI或执行其他逻辑
    }*/
    
    private func checkModelsForPrediction(with data: DataSnapshot) {
        guard isRecording else { return }

        for i in 0..<data.predictTime {
            //let dataPerTime =
            for model in modelManager.selectedModelInfos {
                let modelName = model.modelName
                //print(modelName)
                if var remaining = modelRemainingSamples[modelName] {
                    //print(remaining)
                    remaining -= 1
                    if remaining <= 0 {
                        // 到达预测时机
                        let lastToEnd = data.predictTime - i - 1
                        let total = data.phoneSlice.count - lastToEnd
                        // 数据不足时跳过此次预测
                        if total >= model.inputWindowInSamples {
                            performPrediction(for: model, with: data, atLast: lastToEnd)
                        }
                    } else {
                        modelRemainingSamples[modelName] = remaining
                    }
                }
            }
        }
    }
        
    private func performPrediction(for model: AnyPredictionModel, with data: DataSnapshot, atLast lastToEnd: Int) {
        // 获取模型需要的输入数据(最近model.inputWindowInSamples条数据)
        let inputData = model.isPhoneData
        ? getLastPhoneSamples(count: model.inputWindowInSamples, data: data.phoneSlice, before: lastToEnd)
        : getLastSensorSamples(sensorLocation: model.sensorLocation, count: model.inputWindowInSamples, data: data.sensorSlice, before: lastToEnd)
        
        model.predict(inputData: inputData) { [weak self] result in
            guard let self = self else { return }
            // 根据结果调整下次预测的时机
            if model.requiresDecisionBasedInterval {
                self.modelRemainingSamples[model.modelName] = model.adjustPredictionInterval(basedOn: result)
            } else {
                self.modelRemainingSamples[model.modelName] = model.predictionIntervalInSamples
            }
            // 处理预测结果，确保在主线程上更新
            if let resultBool = result as? Bool, resultBool == true {
                DispatchQueue.main.async {
                    self.predictResultCnt += 1
                    //self.modelResults[model.modelName] = result
                    //self.compensationTime += model.compensationValue
                }
            }
            //self.handleModelPrediction(modelName: model.modelName, result: result)
        }
    }
    
    // 返回手机端原始最新待预测数据
    func getLastPhoneSamples(count: Int, data: [PhoneData?], before: Int) -> [Float] {
        let total = data.count - before
        let startIndex = max(total - count, 0)
        let recentData = Array(data[startIndex..<total])
        let recentDataFloat = convertPhoneToFloatArray(phoneData: recentData)
        
        return recentDataFloat
    }
    
    // 返回多设备端传感器最新待预测数据并预处理
    func getLastSensorSamples(sensorLocation: Int, count: Int, data: [[SensorTrainingData?]], before: Int) -> [Float] {
        var result: [SensorTrainingData?] = []
        let deviceNum = dataFusionManager.sensorDeviceCount
        // 依次检查 sensorLocation 的 bit0 ~ bit5
        for i in 0..<deviceNum + 1 {
            // (1 << i) 表示第 i 位的掩码(1,2,4,8,16)，与 sensorLocation 做与运算检查是否为 1
            if (sensorLocation & (1 << i)) != 0 {
                let sourceArray = data[i]
                // 若 sourceArray 数量不足 count，则直接全部取；否则取后 count 个
                let total = sourceArray.count - before
                let startIndex = max(0, total - count)
                let lastPart = sourceArray[startIndex..<total]
                result.append(contentsOf: lastPart)
            }
        }
        let resultFloat = convertSensorToFloatArray(sensorData: result)
        
        return resultFloat
    }
    
    func convertPhoneToFloatArray(phoneData: [PhoneData?]) -> [Float] {
        var result: [Float] = []
        
        for data in phoneData {
            if let data = data {
                // 如果数据不为 nil，则将其值转换为 Float 并加入结果数组
                result.append(contentsOf: [
                    Float(data.accX),
                    Float(data.accY),
                    Float(data.accZ),
                    Float(data.gyroX),
                    Float(data.gyroY),
                    Float(data.gyroZ),
                    Float(data.magX),
                    Float(data.magY),
                    Float(data.magZ)
                ])
            } else {
                // 如果数据为 nil，则用 0 来占位
                result.append(contentsOf: [0, 0, 0, 0, 0, 0, 0, 0, 0])
            }
        }
        return result
    }
    
    func convertSensorToFloatArray(sensorData: [SensorTrainingData?]) -> [Float] {
        var result: [Float] = []
        
        for data in sensorData {
            if let data = data {
                // 如果数据不为 nil，则将其值转换为 Float 并加入结果数组
                result.append(contentsOf: [
                    Float(data.accX),
                    Float(data.accY),
                    Float(data.accZ),
                    Float(data.gyroX),
                    Float(data.gyroY),
                    Float(data.gyroZ)
                ])
            } else {
                // 如果数据为 nil，则用 0 来占位
                result.append(contentsOf: [0, 0, 0, 0, 0, 0])
            }
        }
        
        return result
    }
    
    // Request microphone access
    private func requestMicrophoneAccess() {
        AVAudioApplication.requestRecordPermission(completionHandler: { [weak self] granted in
            if granted {
                self?.setupAudioRecorder()
            } else {
                Logger.competition.notice_public("Microphone access denied.")
            }
        })
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
            alertTitle = "无法开始比赛"
            alertMessage = "需要后台定位权限以进行持续的比赛记录。"
            showAlert = true
            return
        }
        // 检查麦克风权限
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            // 权限已授予，开始录音
            startRecordingSession()
        case .denied:
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
        }
    }
    
    func stopCompetition() {
        isRecording = false

        // 单人模式下，修改服务端对应用户的record信息，更新排行榜
        currentCompetitionRecord?.duration = dataFusionManager.elapsedTime
        if let start = currentCompetitionRecord?.startDate {
            currentCompetitionRecord?.completionDate = start + dataFusionManager.elapsedTime
        }
        if let record = currentCompetitionRecord {
            // 组队模式下，修改服务端对应用户的record信息，修改对应team中其余member用户的record向其teamMember中添加成员，
            // 修改team的member中用户的完成状态，最后检查如果team.member全部完成则删除team，更新排行榜
            if record.isTeamCompetition {
                stopCompetitionInTeamMode()
            }
            
            deleteCompetitionRecord(id: record.id, status: record.status)
        }
        addCompetitionRecord()
        resetCompetitionProperties()
        
        modelRemainingSamples.removeAll()
        
        // Stop location updates
        deleteCompetitionLocationSubscription()
        LocationManager.shared.backToLastSet()
        //locationManager.stopUpdatingHeading()
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
        motionManager.stopMagnetometerUpdates()
        
        // Stop audio recording if applicable
        stopRecordingAudio()
        
        // 停止手机和传感器设备的数据收集
        self.stopTimer()
        for (pos, dev) in deviceManager.deviceMap {
            if let device = dev {
                stopCollecting(device: device)
            }
        }
        
        if SAVEPHONEDATA {
            self.finalizeCompetitionData()
        }
        
        predictResultCnt = 0
        
        dataFusionManager.resetAll()
        modelManager.resetAll()
        Logger.competition.notice_public("competition stop")
    }
    
    func startRecordingSession() {
        // 重置组队模式下的计时环境
        stopAllTeamJoinTimers()
        teamJoinRemainingTime = teamJoinTimeWindow
        isTeamJoinWindowExpired = false
        
        startTime = Date()
        isRecording = true
        competitionData = []
        
        if let record = currentCompetitionRecord {
            // 单人模式下，修改服务端record的startDate和status
            deleteCompetitionRecord(id: record.id, status: record.status)
            currentCompetitionRecord?.startDate = startTime
            currentCompetitionRecord?.status = .completed
            addCompetitionRecord()
            
            // 组队模式下，向服务端对应team中member剩余成员的record.teamMember加入用户并写入startDate，
            // 更新team的realstarttime和status，修改用户record的status和startDate
            if record.isTeamCompetition {
                startCompetitionInTeamMode()
            }
        }
        
        // 初始化模型剩余样本数
        for model in modelManager.selectedModelInfos {
            modelRemainingSamples[model.modelName] = model.predictionIntervalInSamples
        }
        
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
        dataFusionManager.setPredictWindow(maxWindow: modelManager.maxInputWindow)
        
        // 所有设备开始收集数据
        if isNeedPhoneData {
            dataFusionManager.deviceNeedToWork |= 0b000001
        }
        for (pos, dev) in deviceManager.deviceMap {
            if let device = dev, (sensorRequest & (1 << pos.rawValue)) != 0 {
                dataFusionManager.deviceNeedToWork |= (1 << (pos.rawValue + 1))
                startCollecting(device: device)
            }
        }
    }
    
    func startCollecting(device: SensorDeviceProtocol) {
        // 每秒检查一次连接状态
        collectionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // 检查是否连接成功
            if device.connect() {
                Logger.competition.notice_public("watch data start collecting")
                device.startCollection()  // 开始数据收集
                self.collectionTimer?.invalidate()  // 停止定时器
            } else {
                Logger.competition.notice_public("watch not connected, retrying...")
            }
        }
    }
    
    func stopCollecting(device: SensorDeviceProtocol) {
        // 每秒检查一次连接状态
        collectionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // 检查是否连接成功
            if device.connect() {
                Logger.competition.notice_public("watch data stop collecting")
                device.stopCollection()  // 停止数据收集
                self.collectionTimer?.invalidate()  // 停止定时器
            } else {
                Logger.competition.notice_public("watch not connected, retrying...")
            }
        }
    }
    
    // 启动定时器
    private func startTimer() {
        // 在比赛开始时已记录下 startTime = Date()
        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now(), repeating: 0.05) // 每0.05秒触发一次
        var counter = 0 // 用于计数，每次事件触发加1
        
        timer.setEventHandler { [weak self] in
            guard let self = self, self.isRecording, let start = self.startTime else { return }
            
            // 1. 记录数据
            self.recordMotionData()
            
            // 2. 更新计数器
            counter += 1
            
            // 每20次更新一次 elapsedTime，相当于1秒更新一次（20 * 0.05s = 1s）
            if counter >= 20 {
                counter = 0
                let newElapsedTime = Date().timeIntervalSince(start)
                DispatchQueue.main.async {
                    self.dataFusionManager.elapsedTime = newElapsedTime
                }
            }
        }
        self.timer = timer
        timer.resume()
        Logger.competition.notice_public("phone data start collecting.")
    }
    
    // 停止定时器
    private func stopTimer() {
        collectionTimer?.invalidate()
        collectionTimer = nil
        timer?.cancel()
        timer = nil
        Logger.competition.notice_public("phone data stop collecting.")
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
    
    // 添加新的比赛记录(比赛未开始或比赛完成即退出比赛链路)
    func addCompetitionRecord() {
        if let record = currentCompetitionRecord {
            let exists = competitionRecords.contains { $0.id == record.id && $0.status == record.status }
            if !exists {
                competitionRecords.append(record)
            }
        }
    }
    
    // 删除已存在的比赛记录
    func deleteCompetitionRecord(id: UUID, status: CompetitionStatus) {
        competitionRecords.removeAll { $0.id == id && $0.status == status }
    }
    
    // 重置currentCompetitionRecord
    func resetCompetitionRecord(record: CompetitionRecord) {
        currentCompetitionRecord = record
        startCoordinate = record.trackStart
        endCoordinate = record.trackEnd
    }
    
    func SelectedCards(_ cards: [MagicCard]) {
        guard cards.count <= 3 else {
            print("最多选择3个卡片")
            return
        }
        for card in cards {
            sensorRequest |= card.sensorLocation
        }
        self.selectedCards = cards
    }
    
    func resetCompetitionProperties() {
        teamJoinRemainingTime = teamJoinTimeWindow
        isTeamJoinWindowExpired = false
        currentCompetitionRecord = nil
        selectedCards.removeAll()
        sensorRequest = 0
        startCoordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        endCoordinate = CLLocationCoordinate2D(latitude: 1, longitude: 1)
    }
    
    // 假设所有比赛中赛道的队伍都一样，本地测试用
    func generateDummyAvailableTeams(eventId: Int, trackId: Int) -> [Team] {
        let team1 = Team(
            teamID: "team001",
            captainID: "123",
            captainName: "张伟",
            captainAvatar: "person.circle",
            title: "城市定向高手队",
            description: "有经验的城市定向赛玩家组队",
            maxMembers: 6,
            members: [
                TeamMember(userID: "123", name: "张伟", avatar: "person.circle", isLeader: true, joinTime: Date().addingTimeInterval(-86400 * 4), isRegistered: true),
                TeamMember(userID: "124", name: "王芳", avatar: "person.circle", isLeader: false, joinTime: Date().addingTimeInterval(-86400 * 3), isRegistered: false)
            ],
            teamCode: "DEF456",
            eventName: "上海城市定向赛",
            trackName: "高级赛道",
            //trackID: trackId,
            //eventID: eventId,
            creationDate: Date().addingTimeInterval(-86400 * 4),
            competitionDate: Date().addingTimeInterval(86400 * 20),
            pendingRequests: [],
            isPublic: true
        )
        
        let team2 = Team(
            teamID: "team002",
            captainID: "555",
            captainName: "李明",
            captainAvatar: "person.circle",
            title: "轻松跑团",
            description: "享受跑步的乐趣，不在乎名次",
            maxMembers: 10,
            members: [
                TeamMember(userID: "555", name: "李明", avatar: "person.circle", isLeader: true, joinTime: Date().addingTimeInterval(-86400 * 2), isRegistered: true),
                TeamMember(userID: "556",name: "赵丽", avatar: "person.circle", isLeader: false, joinTime: Date().addingTimeInterval(-86400), isRegistered: true),
                TeamMember(userID: "557",name: "孙悟空", avatar: "person.circle", isLeader: false, joinTime: Date(), isRegistered: true)
            ],
            teamCode: "GHI789",
            eventName: "上海城市定向赛",
            trackName: "高级赛道",
            //trackID: trackId,
            //eventID: eventId,
            creationDate: Date().addingTimeInterval(-86400 * 2),
            competitionDate: Date().addingTimeInterval(86400 * 25),
            pendingRequests: [],
            isPublic: true
        )
        
        return [team1, team2]
    }
    
    // 本地测试使用
    func generateDummyJoinedTeams() -> [Team] {
        let team1 = Team(
            teamID: "team001",
            captainID: "123",
            captainName: "张伟",
            captainAvatar: "person.circle",
            title: "城市定向高手队",
            description: "有经验的城市定向赛玩家组队",
            maxMembers: 6,
            members: [
                TeamMember(userID: "123", name: "张伟", avatar: "person.circle", isLeader: true, joinTime: Date().addingTimeInterval(-86400 * 4), isRegistered: true),
                TeamMember(userID: "124", name: "王芳", avatar: "person.circle", isLeader: false, joinTime: Date().addingTimeInterval(-86400 * 3), isRegistered: true),
                TeamMember(userID: "125", name: "张伟", avatar: "person.circle", isLeader: false, joinTime: Date().addingTimeInterval(-86400 * 4), isRegistered: true),
                TeamMember(userID: "126", name: "王芳", avatar: "person.circle", isLeader: false, joinTime: Date().addingTimeInterval(-86400 * 3), isRegistered: true),
                TeamMember(userID: "127", name: "张伟", avatar: "person.circle", isLeader: false, joinTime: Date().addingTimeInterval(-86400 * 4), isRegistered: true),
                TeamMember(userID: "user_555", name: "Newuser_10358", avatar: "person.circle", isLeader: false, joinTime: Date().addingTimeInterval(-86400 * 3), isRegistered: false)
            ],
            teamCode: "11RJ11",
            eventName: "上海城市跑酷赛",
            trackName: "红牛赛道",
            //trackID: 0,
            //eventID: 0,
            creationDate: Date().addingTimeInterval(-86400 * 4),
            competitionDate: Date().addingTimeInterval(86400 * 20),
            pendingRequests: [],
            isPublic: true,
            realCompetitionDate: Date(),
            isLocked: true,
            status: .recording
        )
        
        availableTeams.append(team1)
        
        return [team1]
    }
    
    func getTeamTimestampInSeconds(teamCode: String) -> Int? {
        let joinedTeams = myJoinedTeams + myCreatedTeams
        if let index = joinedTeams.firstIndex(where: { $0.teamCode == teamCode }) {
            if let startTime = joinedTeams[index].realCompetitionDate {
                let stamp = Int(Date().timeIntervalSince(startTime))
                return stamp
            } else {
                return nil
            }
        }
        return nil
    }
    
    // 组队模式下开始比赛时尝试向服务端team写入最早时间并修改状态，同时修改所有成员的record
    func startCompetitionInTeamMode() {
        let joinedTeams = myJoinedTeams + myCreatedTeams
        
        if let record = currentCompetitionRecord, let index = joinedTeams.firstIndex(where: { $0.teamCode == record.teamCode }) {
            if joinedTeams[index].realCompetitionDate != nil {
                return
            } else {
                if let joinedIndex = myJoinedTeams.firstIndex(where: { $0.teamCode == record.teamCode }) {
                    myJoinedTeams[joinedIndex].realCompetitionDate = Date()
                    myJoinedTeams[joinedIndex].status = .recording
                }
                if let createdIndex = myCreatedTeams.firstIndex(where: { $0.teamCode == record.teamCode }) {
                    myCreatedTeams[createdIndex].realCompetitionDate = Date()
                    myCreatedTeams[createdIndex].status = .recording
                }
            }
        }
    }
    
    // 组队模式下结束比赛时需要修改服务端team数据，以及team中所有member的record
    func stopCompetitionInTeamMode() {
        
    }
    
    // 服务端需定期处理异常的team
    // 针对prepared状态的team不做处理
    // 针对ready状态的team，比赛时间24h后删除team
    // 针对recording状态的team，检查realstarttime，超过2h后将member里的所有未完成比赛的成员record状态调整为completed，并删除team
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
