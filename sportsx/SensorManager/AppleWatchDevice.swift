//
//  AppleWatchDevice.swift
//  sportsx
//
//  apple watch 目前测试无法支持磁力计数据获取
//
//  Created by 任杰 on 2025/1/8.
//

import Foundation
import Combine
import WatchConnectivity
import HealthKit
import CoreLocation
import os


class AppleWatchDevice: NSObject, SensorDeviceProtocol, ObservableObject {
    // 协议要求
    let deviceID: String
    let deviceName: String
    let sensorPos: Int
    let dataFusionManager = DataFusionManager.shared
    let competitionManager = CompetitionManager.shared
    
    var canReceiveData: Bool
    var enableIMU: Bool
    
    private var session: WCSession
    
    // 仅用于保存传感器数据到本地调试
    private var competitionData: [SensorData] = []
    private let batchSize = 60 // 每次采集60条数据后写入文件
    let healthStore = HKHealthStore()

    // 手机→手表实时负载推送：运动期间每 3s 一次（对齐 recordPath 的 pace 重算节奏）
    private var liveTimer: DispatchSourceTimer?
    private let liveTimerQueue = DispatchQueue(label: "com.sportsx.watch.livepush", qos: .utility)

    // free training 网格推送：移动门控 + 集合变化才发
    private var lastGridQueryLocation: CLLocation?
    private var lastPushedGridKeys: [String] = []
    private let gridQueryMoveThreshold: CLLocationDistance = 100   // 移动 ≥100m 才重查

    // 附近奖励网格响应（仅解码手表需要的字段）
    private struct NearbyGridsResponse: Codable {
        struct Grid: Codable {
            let grid_x: Int
            let grid_y: Int
            let center_lat: Double
            let center_lon: Double
            let reward_type: String
            let reward_count: Int
        }
        let grids: [Grid]
    }

    init(deviceID: String, deviceName: String, sensorPos: Int) {
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.sensorPos = sensorPos
        self.canReceiveData = false
        self.enableIMU = false
        self.session = WCSession.default
    }
    
    // 销毁前重置代理兜底
    //deinit {
    //    self.session.delegate = DeviceManager.shared
    //}
    
    func connect() -> Bool {
        // 先检查是否配对
        guard session.isPaired else {
            //Logger.competition.notice_public("[AppleWatchDevice] connect() failed: Apple Watch not paired.")
            return false
        }
        
        // 检查是否安装了 Watch App
        guard session.isWatchAppInstalled else {
            //Logger.competition.notice_public("[AppleWatchDevice] connect() failed: Watch App is not installed.")
            return false
        }
        
        // 检查 activationState
        if session.activationState == .activated {
            //Logger.competition.notice_public("[AppleWatchDevice] connect() success.")
            // 连接成功后切换代理
            session.delegate = self
            return true
        } else {
            //Logger.competition.notice_public("[AppleWatchDevice] connect() failed.")
            return false
        }
    }
    
    func disconnect() {
        // WatchConnectivity 可能无法像BLE那样“主动断开”，可以做一些标记
        // 重置代理，否则session状态会发生变化
        session.delegate = DeviceManager.shared
    }
    
    func startCollection(activityType: SportName, locationType: String) {
        guard session.activationState == .activated else {
            let toast = Toast(message: "competition.applewatch.error.connect")
            ToastManager.shared.show(toast: toast)
            Logger.competition.notice_public("[AppleWatchDevice] WCSession not activated, cannot update start context.")
            return
        }
        canReceiveData = true
        competitionData = []
        
        // 动态配置运动类型
        let config = HKWorkoutConfiguration()
        switch activityType {
        case .Running:
            config.activityType = .running
        case .Bike:
            config.activityType = .cycling
        default:
            config.activityType = .other
        }
        config.locationType = (locationType.lowercased() == "indoor") ? .indoor : .outdoor
        
        // 启动 watchapp 并开启 workout
        if HKHealthStore.isHealthDataAvailable() {
            Task {
                do {
                    try await healthStore.startWatchApp(toHandle: config)
                }
                catch {
                    await MainActor.run {
                        let toast = Toast(message: "competition.applewatch.error.sync")
                        ToastManager.shared.show(toast: toast)
                        Logger.competition.notice_public("[AppleWatchDevice] start workout error: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            let toast = Toast(message: "competition.applewatch.error.sync")
            ToastManager.shared.show(toast: toast)
        }
        
        // watch端可主动同步状态来兜底
        do {
            let context: [String: Any] = [
                "command": "startCollection",
                "enableIMU": enableIMU,
                "activityType": activityType.rawValue,
                "locationType": locationType,
                "mode": currentWatchMode(),                 // race / route_training / free_training
                "timestamp": Date().timeIntervalSince1970  // 给个时间戳避免被认为是旧状态
            ]
            try session.updateApplicationContext(context)
            Logger.competition.notice_public("[AppleWatchDevice] Sent startCollecting state via applicationContext.")
        } catch {
            Logger.competition.notice_public("[AppleWatchDevice] Failed to update start applicationContext: \(error)")
        }

        startLivePush()
    }
    
    func stopCollection() {
        stopLivePush()
        guard session.activationState == .activated else {
            let toast = Toast(message: "competition.applewatch.error.finish")
            ToastManager.shared.show(toast: toast)
            Logger.competition.notice_public("[AppleWatchDevice] WCSession not activated, cannot update stop context.")
            return
        }
        do {
            let context: [String: Any] = [
                "command": "stopCollection",
                "timestamp": Date().timeIntervalSince1970  // 给个时间戳避免被认为是旧状态
            ]
            try session.updateApplicationContext(context)
            Logger.competition.notice_public("[AppleWatchDevice] Sent stopCollecting state via applicationContext.")
        } catch {
            Logger.competition.notice_public("[AppleWatchDevice] Failed to update stop applicationContext: \(error)")
        }
#if DEBUG
        if SAVESENSORDATA {
            self.finalizeCompetitionData()
        }
#endif
        canReceiveData = false
        enableIMU = false
    }
    
    // 保存批次数据为CSV
    private func saveBatchAsCSV(dataBatch: [SensorData]) {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent("competitionData_watch.csv")
        
        if !fileManager.fileExists(atPath: fileURL.path) {
            let csvHeader = "timestamp,acc_x,acc_y,acc_z,gyro_x,gyro_y,gyro_z,mag_x,mag_y,mag_z\n"
            do {
                try csvHeader.write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                Logger.competition.notice_public("[AppleWatchDevice] Failed to write CSV header: \(error)")
                return
            }
        }
        
        var csvString = ""
        let dateFormatter = ISO8601DateFormatter()
        
        for data in dataBatch {
            let timestamp = data.timestamp
            let accX = data.accX
            let accY = data.accY
            let accZ = data.accZ
            let gyroX = data.gyroX
            let gyroY = data.gyroY
            let gyroZ = data.gyroZ
            
            let row = "\(timestamp),\(accX),\(accY),\(accZ),\(gyroX),\(gyroY),\(gyroZ)\n"
            csvString.append(row)
        }
        
        if let dataToAppend = csvString.data(using: .utf8) {
            do {
                let fileHandle = try FileHandle(forWritingTo: fileURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(dataToAppend)
                fileHandle.closeFile()
                //print("watch Batch saved as CSV.")
            } catch {
                Logger.competition.notice_public("[AppleWatchDevice] Failed to append watch CSV: \(error)")
            }
        }
    }
    
    // 结束比赛，保存剩余数据
    private func finalizeCompetitionData() {
        if competitionData.isEmpty { return }
        
        let batch = competitionData
        competitionData.removeAll()
        saveBatchAsCSV(dataBatch: batch)
        
        //print("Watch Competition data finalized.")
    }

    // MARK: - 手机→手表实时负载

    // 当前运动 mode（取自比赛/训练特征），随握手发给手表
    private func currentWatchMode() -> String {
        switch competitionManager.sportFeature?.featureType {
        case .race: return "race"
        case .routeTraining: return "route_training"
        case .freeTraining: return "free_training"
        default: return "free_training"
        }
    }

    private func startLivePush() {
        lastGridQueryLocation = nil
        lastPushedGridKeys = []
        liveTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: liveTimerQueue)
        timer.schedule(deadline: .now() + 3.0, repeating: 3.0)
        timer.setEventHandler { [weak self] in
            self?.pushLivePayload()
        }
        liveTimer = timer
        timer.resume()
    }

    private func stopLivePush() {
        liveTimer?.cancel()
        liveTimer = nil
    }

    // 每 3s 触发一次；可达才发，不可达直接丢弃（手表保留上一值）
    private func pushLivePayload() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.canReceiveData,
                  self.session.activationState == .activated,
                  self.session.isReachable else { return }

            switch self.currentWatchMode() {
            case "race", "route_training":
                self.pushPacePayload()
            case "free_training":
                self.pushNearbyGridsIfNeeded()
            default:
                break
            }
        }
    }

    // race / route：推 pace 预测 + PB 对比
    private func pushPacePayload() {
        var live: [String: Any] = [
            "total": competitionManager.pacePredictedTotal,
            "hasPB": competitionManager.paceHasPB,
            "locked": !UserManager.shared.user.isVip   // 非订阅用户手表侧同样打码为 --
        ]
        if let rank = competitionManager.pacePredictedRank { live["rank"] = rank }
        if let dt = competitionManager.paceDeltaTime { live["pbDeltaTime"] = dt }
        if let dd = competitionManager.paceDeltaDistance { live["pbDeltaDistance"] = dd }

        session.sendMessage(["live": live], replyHandler: nil) { error in
            Logger.competition.notice_public("[AppleWatchDevice] pace push failed: \(error.localizedDescription)")
        }
    }

    // free：移动 ≥ 阈值才重查附近奖励网格，集合变化才推
    private func pushNearbyGridsIfNeeded() {
        guard let loc = LocationManager.shared.getLocation() else { return }
        if let last = lastGridQueryLocation, loc.distance(from: last) < gridQueryMoveThreshold { return }
        guard let sport = competitionManager.sport?.rawValue else { return }   // "bike" / "running"
        lastGridQueryLocation = loc
        Task { [weak self] in
            await self?.queryAndPushGrids(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude, sport: sport)
        }
    }

    private func queryAndPushGrids(lat: Double, lon: Double, sport: String) async {
        var components = URLComponents(string: "/training/\(sport)/query_nearby_grids")
        components?.queryItems = [
            URLQueryItem(name: "lat", value: "\(lat)"),
            URLQueryItem(name: "lon", value: "\(lon)"),
            URLQueryItem(name: "count", value: "3")
        ]
        guard let path = components?.string else { return }

        let request = APIRequest(path: path, method: .get, requiresAuth: true)
        let result = await NetworkService.sendAsyncRequest(with: request, decodingType: NearbyGridsResponse.self)
        guard case .success(let data?) = result else { return }

        await MainActor.run {
            guard self.canReceiveData, self.session.isReachable else { return }
            let keys = data.grids.map { "\($0.grid_x),\($0.grid_y)" }
            guard keys != self.lastPushedGridKeys else { return }   // 集合没变不重复推
            self.lastPushedGridKeys = keys

            let payload: [[String: Any]] = data.grids.map {
                ["gx": $0.grid_x, "gy": $0.grid_y,
                 "lat": $0.center_lat, "lon": $0.center_lon,
                 "reward": $0.reward_type, "count": $0.reward_count]
            }
            self.session.sendMessage(["live": ["grids": payload]], replyHandler: nil) { error in
                Logger.competition.notice_public("[AppleWatchDevice] grids push failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - WCSessionDelegate
extension AppleWatchDevice: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Logger.competition.notice_public("[AppleWatchDevice] activationDidComplete. State: \(activationState.rawValue), Error: \(String(describing: error))")
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        // iOS 13+ 可能会用到
        Logger.competition.notice_public("[AppleWatchDevice] Watch become inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        // iOS 13+ 可能会用到
        // 重新激活
        Logger.competition.notice_public("[AppleWatchDevice] Watch deactivate")
        session.activate()
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Watch 端用 sendMessage(["watchBatch": [ ... ]]) 的场景
        if let batchArray = message["IMUBatch"] as? [[String: Any]] {
            //Logger.competition.notice_public("IMUBatch")
            var batchData = [SensorData]()
            var cnt = 0
            //Logger.competition.notice_public("Start convert message...")
            for item in batchArray {
                cnt += 1
                if let timestamp = item["timestamp"] as? TimeInterval,
                   let accx = item["accX"] as? Double,
                   let accy = item["accY"] as? Double,
                   let accz = item["accZ"] as? Double,
                   let gyrox = item["gyroX"] as? Double,
                   let gyroy = item["gyroY"] as? Double,
                   let gyroz = item["gyroZ"] as? Double {
                    let sensorData = SensorData(
                        timestamp: timestamp,
                        accX: accx,
                        accY: accy,
                        accZ: accz,
                        gyroX: gyrox,
                        gyroY: gyroy,
                        gyroZ: gyroz
                    )
                    batchData.append(sensorData)
#if DEBUG
                    if SAVESENSORDATA {
                        competitionData.append(sensorData)
                    }
#endif
                }
            }
            //Logger.competition.notice_public("receive batch size : ", cnt)
            if canReceiveData && enableIMU {
                //Logger.competition.notice_public("add batch data")
                dataFusionManager.addSensorData(sensorPos, batchData)
            }
#if DEBUG
            if SAVESENSORDATA {
                // 批量保存
                if competitionData.count >= batchSize {
                    let batch = competitionData
                    competitionData.removeAll()
                    saveBatchAsCSV(dataBatch: batch)
                }
            }
#endif
        }
        if let statsData = message["statsData"] as? [String: Any] {
            //Logger.competition.notice_public("statsData")
            if canReceiveData {
                //Logger.competition.notice_public("set statsData")
                competitionManager.handleStatsData(stats: statsData)
            }
        }
    }
}
