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

class AppleWatchDevice: NSObject, SensorDeviceProtocol, ObservableObject {
    // 协议要求
    var deviceID: String
    var deviceName: String
    var sensorPos: Int
    var dataFusionManager: DataFusionManager
    
    @Published var isConnected: Bool = false
    
    private var session: WCSession?
    
    // 仅用于保存传感器数据到本地调试
    private var competitionData: [SensorData] = []
    private let batchSize = 60 // 每次采集60条数据后写入文件
    
    /// 初始化时，激活 WCSession
    init(deviceID: String, deviceName: String, sensorPos: Int, dataFusionManager: DataFusionManager) {
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.sensorPos = sensorPos
        self.dataFusionManager = dataFusionManager
        super.init()
        
        if WCSession.isSupported() {
            let s = WCSession.default
            s.delegate = self
            s.activate() // 异步激活
            self.session = s
        } else {
            print("[AppleWatchDevice] WCSession not supported on this device.")
        }
    }
    
    func connect() -> Bool {
        guard let session = session else {
            print("[AppleWatchDevice] connect() failed: session is nil.")
            //self.isConnected = false
            return false
        }
        
        // 先检查是否配对
        guard session.isPaired else {
            print("[AppleWatchDevice] connect() failed: Apple Watch not paired.")
            //self.isConnected = false
            return false
        }
        
        // 检查是否安装了 Watch App
        guard session.isWatchAppInstalled else {
            print("[AppleWatchDevice] connect() failed: Watch App is not installed.")
            //self.isConnected = false
            return false
        }
        
        // 检查 isReachable
        if session.activationState == .activated && isConnected {
            print("[AppleWatchDevice] connect() success.")
            //self.isConnected = true
            return true
        } else {
            print("[AppleWatchDevice] connect() failed.")
            //self.isConnected = false
            return false
            /*DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if session.isReachable {
                    self.isConnected = true
                    completion(true)
                } else {
                    print("[AppleWatchDevice] connect() - still not reachable after wait.")
                    completion(false)
                }
            }*/
        }
    }
    
    func disconnect() {
        // WatchConnectivity 可能无法像BLE那样“主动断开”，可以做一些标记
        self.isConnected = false
    }
    
    func startCollection() {
        competitionData = []
        // 给 Watch 端发消息，表示“请开始采集”
        guard isConnected, let session = session else {
            print("[WatchSensorManager] session not reachable, cannot start watch collection.")
            return
        }
        print("Start send collect command...")
        session.sendMessage(["command": "startCollection"], replyHandler: nil, errorHandler: { error in
            print("[WatchSensorManager] Error sending startCollection command: \(error)")
        })
    }
        
    func stopCollection() {
        guard isConnected, let session = session else {
            print("[WatchSensorManager] session not reachable, cannot stop watch collection.")
            return
        }
        
        session.sendMessage(["command": "stopCollection"], replyHandler: nil, errorHandler: { error in
            print("[WatchSensorManager] Error sending stopCollection command: \(error)")
        })
        
        if SAVESENSORDATA {
            self.finalizeCompetitionData()
        }
    }
    
    // 保存批次数据为CSV
    private func saveBatchAsCSV(dataBatch: [SensorData]) {
        // 定义CSV文件路径
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent("competitionData_watch.csv")
        
        // 如果文件不存在，创建并写入头部
        if !fileManager.fileExists(atPath: fileURL.path) {
            let csvHeader = "timestamp,acc_x,acc_y,acc_z,gyro_x,gyro_y,gyro_z,mag_x,mag_y,mag_z\n"
            do {
                try csvHeader.write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                print("Failed to write CSV header: \(error)")
                return
            }
        }
        
        // 构建CSV内容
        var csvString = ""
        let dateFormatter = ISO8601DateFormatter()
        
        for data in dataBatch {
            let timestamp = dateFormatter.string(from: data.timestamp)
            let accX = data.accX
            let accY = data.accY
            let accZ = data.accZ
            let gyroX = data.gyroX
            let gyroY = data.gyroY
            let gyroZ = data.gyroZ
            //let magX = data.magX
            //let magY = data.magY
            //let magZ = data.magZ
            
            let row = "\(timestamp),\(accX),\(accY),\(accZ),\(gyroX),\(gyroY),\(gyroZ)\n"
            csvString.append(row)
        }
        
        // 追加到CSV文件
        if let dataToAppend = csvString.data(using: .utf8) {
            do {
                let fileHandle = try FileHandle(forWritingTo: fileURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(dataToAppend)
                fileHandle.closeFile()
                print("watch Batch saved as CSV.")
            } catch {
                print("Failed to append watch CSV: \(error)")
            }
        }
    }
    
    // 结束比赛，保存剩余数据
    private func finalizeCompetitionData() {
        if competitionData.isEmpty { return }
        
        let batch = competitionData
        competitionData.removeAll()
        saveBatchAsCSV(dataBatch: batch)
        
        print("Watch Competition data finalized.")
    }
}

// MARK: - WCSessionDelegate
extension AppleWatchDevice: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("[WatchSensorManager] activationDidComplete. State: \(activationState.rawValue), Error: \(String(describing: error))")
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        // iOS 13+ 可能会用到
        print("[AppleWatchDevice] Watch become inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        // iOS 13+ 可能会用到
        // 重新激活
        print("[AppleWatchDevice] Watch deactivate")
        session.activate()
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable {
            print("[AppleWatchDevice] Watch is now reachable.")
            self.isConnected = true
        } else {
            print("[AppleWatchDevice] Watch is no longer reachable.")
            self.isConnected = false
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Watch 端用 sendMessage(["watchBatch": [ ... ]]) 的场景
        if let batchArray = message["watchBatch"] as? [[String: Any]] {
            var batchData = [SensorData]()
            var cnt = 0
            print("Start convert message...")
            for item in batchArray {
                cnt += 1
                if let timestamp = item["timestamp"] as? Date,
                   let accx = item["accX"] as? Double,
                   let accy = item["accY"] as? Double,
                   let accz = item["accZ"] as? Double,
                   let gyrox = item["gyroX"] as? Double,
                   let gyroy = item["gyroY"] as? Double,
                   let gyroz = item["gyroZ"] as? Double
                   /*let magx = item["magX"] as? Double,
                   let magy = item["magY"] as? Double,
                   let magz = item["magZ"] as? Double*/ {
                    let sensorData = SensorData(
                        timestamp: timestamp,
                        accX: accx,
                        accY: accy,
                        accZ: accz,
                        gyroX: gyrox,
                        gyroY: gyroy,
                        gyroZ: gyroz
                        //magX: magx,
                        //magY: magy,
                        //magZ: magz
                    )
                    batchData.append(sensorData)
                    if SAVESENSORDATA {
                        competitionData.append(sensorData)
                    }
                }
            }
            print("batch size : ", cnt)
            dataFusionManager.addSensorData(sensorPos, batchData)
            
            if SAVESENSORDATA {
                // 批量保存
                if competitionData.count >= batchSize {
                    let batch = competitionData
                    competitionData.removeAll()
                    saveBatchAsCSV(dataBatch: batch)
                }
            }
        } else {
            print("Message convert failed")
        }
    }
}
