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
            Logger.competition.notice_public("[AppleWatchDevice] connect() failed: Apple Watch not paired.")
            return false
        }
        
        // 检查是否安装了 Watch App
        guard session.isWatchAppInstalled else {
            Logger.competition.notice_public("[AppleWatchDevice] connect() failed: Watch App is not installed.")
            return false
        }
        
        // 检查 activationState
        if session.activationState == .activated {
            Logger.competition.notice_public("[AppleWatchDevice] connect() success.")
            // 连接成功后切换代理
            session.delegate = self
            return true
        } else {
            Logger.competition.notice_public("[AppleWatchDevice] connect() failed.")
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
            let toast = Toast(message: "watch连接失败")
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
                        let toast = Toast(message: "请在watch端点击同步开始比赛")
                        ToastManager.shared.show(toast: toast)
                        Logger.competition.notice_public("[AppleWatchDevice] start workout error: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            let toast = Toast(message: "请在watch端点击同步开始比赛")
            ToastManager.shared.show(toast: toast)
        }
        
        // watch端可主动同步状态来兜底
        do {
            let context: [String: Any] = [
                "command": "startCollection",
                "enableIMU": enableIMU,
                "activityType": activityType.rawValue,
                "locationType": locationType,
                "timestamp": Date().timeIntervalSince1970  // 给个时间戳避免被认为是旧状态
            ]
            try session.updateApplicationContext(context)
            Logger.competition.notice_public("[AppleWatchDevice] Sent startCollecting state via applicationContext.")
        } catch {
            Logger.competition.notice_public("[AppleWatchDevice] Failed to update start applicationContext: \(error)")
        }
    }
    
    func stopCollection() {
        guard session.activationState == .activated else {
            let toast = Toast(message: "watch连接失败,请手动结束watch上的运动")
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
        
        if SAVESENSORDATA {
            self.finalizeCompetitionData()
        }
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
                    if SAVESENSORDATA {
                        competitionData.append(sensorData)
                    }
                }
            }
            //Logger.competition.notice_public("receive batch size : ", cnt)
            if canReceiveData {
                //Logger.competition.notice_public("add batch data")
                dataFusionManager.addSensorData(sensorPos, batchData)
            }
            
            if SAVESENSORDATA {
                // 批量保存
                if competitionData.count >= batchSize {
                    let batch = competitionData
                    competitionData.removeAll()
                    saveBatchAsCSV(dataBatch: batch)
                }
            }
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
