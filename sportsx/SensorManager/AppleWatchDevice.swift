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

    // free training 网格推送：集合变化才发（数据来源为 CompetitionManager.nearbyGrids）
    private var lastPushedGridKeys: [String] = []

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

    /// 手机→手表下发暂停/恢复命令（仅 free training 使用）。
    /// 手机为唯一真源：无论暂停由手机还是手表发起，最终都由手机调用此方法广播给手表。
    /// reachable 时用 sendMessage 实时下发，并始终用 applicationContext 兜底（带 timestamp/30s 过期，沿用 start/stop 约定）。
    func sendControlCommand(_ command: String) {
        guard session.activationState == .activated else {
            Logger.competition.notice_public("[AppleWatchDevice] WCSession not activated, cannot send control command \(command).")
            return
        }
        let ts = Date().timeIntervalSince1970
        if session.isReachable {
            session.sendMessage(["control": command, "timestamp": ts], replyHandler: nil) { error in
                Logger.competition.notice_public("[AppleWatchDevice] control \(command) sendMessage failed: \(error.localizedDescription)")
            }
        }
        do {
            try session.updateApplicationContext(["command": command, "timestamp": ts])
        } catch {
            Logger.competition.notice_public("[AppleWatchDevice] Failed to update control applicationContext: \(error)")
        }
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

    // free：读取 CompetitionManager 共享的附近网格，集合变化才推给手表
    private func pushNearbyGridsIfNeeded() {
        let grids = competitionManager.nearbyGrids
        let keys = grids.map { $0.id }
        guard keys != lastPushedGridKeys else { return }   // 集合没变不重复推
        lastPushedGridKeys = keys

        let payload: [[String: Any]] = grids.map {
            ["gx": $0.gridX, "gy": $0.gridY,
             "lat": $0.lat, "lon": $0.lon,
             "reward": $0.reward.rawValue, "count": $0.count]
        }
        session.sendMessage(["live": ["grids": payload]], replyHandler: nil) { error in
            Logger.competition.notice_public("[AppleWatchDevice] grids push failed: \(error.localizedDescription)")
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
        // 手表端暂停/恢复/结束命令（仅 free training）：手机为唯一真源
        if let control = message["control"] as? String {
            DispatchQueue.main.async {
                switch control {
                case "pause":
                    self.competitionManager.pauseFreeTraining(fromRemote: true)
                case "resume":
                    self.competitionManager.resumeFreeTraining(fromRemote: true)
                case "stop":
                    // 手表点击结束：由手机真正结束训练（含结算/上传），并经 stopCollection 回发兜底停采
                    self.competitionManager.stopFreeTraining()
                default:
                    break
                }
            }
        }
    }
}
