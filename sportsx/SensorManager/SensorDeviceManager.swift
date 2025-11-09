//
//  SensorDeviceManager.swift
//  sportsx
//
//  Created by 任杰 on 2025/1/9.
//

import Foundation
import WatchConnectivity
import os


enum BodyPosition: Int, CaseIterable, Identifiable {
    var id: Int { rawValue }
    
    case posLH = 0
    case posRH
    case posLF
    case posRF
    case posWST
    
    var name: String {
        switch self {
        case .posLH: return "左手"
        case .posRH: return "右手"
        case .posLF: return "左脚"
        case .posRF: return "右脚"
        case .posWST: return "胸前"
        }
    }
}

// 传感器设备通用协议
protocol SensorDeviceProtocol {
    // 设备的唯一ID或标识，可是UUID、MAC、或自定义
    var deviceID: String { get }
    
    // 设备名称，用于UI显示
    var deviceName: String { get }
    
    // 绑定位置
    var sensorPos: Int { get }
    
    // 数据融合器
    var dataFusionManager: DataFusionManager { get }
    
    // 当前连接状态
    //var isReady: Bool { get }
    
    // 当前可接收数据状态
    var canReceiveData: Bool { get }
    
    // 是否需要收集IMU数据
    var enableIMU: Bool { get set }
    
    // 连接设备
    func connect() -> Bool
    
    // 断开连接
    func disconnect()
    
    // 开始采集
    func startCollection(activityType: SportName, locationType: String)
    
    // 停止采集
    func stopCollection()
}

// DeviceManager负责管理传感器设备（考虑到AW的特殊性，WCSession的激活和大部分时间的代理放在这里）
class DeviceManager: NSObject, ObservableObject {
    static let shared = DeviceManager()
    // 利用一个字典存储绑定的设备；如果没有绑定则为 nil
    @Published private(set) var deviceMap: [BodyPosition: SensorDeviceProtocol?] = [
        .posLH: nil,
        .posRH: nil,
        .posLF: nil,
        .posRF: nil,
        .posWST: nil
    ]
    
    /// 用一个 Int (低5位) 记录 5 个位置是否已绑定
    /// bit0 对应 position0, bit1 对应 position1, ...
    @Published private(set) var bindingState: Int = 0
    
    private override init() {}
    
    // 绑定设备
    func bindDevice(_ device: SensorDeviceProtocol, at position: BodyPosition) {
        deviceMap[position] = device
        // 设置对应 bit
        bindingState |= (1 << position.rawValue)
    }
    
    // 解绑设备
    func unbindDevice(at position: BodyPosition) {
        // 如果已经有设备, 先断开连接(可选)
        if let existingDevice = deviceMap[position] {
            existingDevice?.disconnect()
        }
        deviceMap[position] = nil
        // 清除对应 bit
        bindingState &= ~(1 << position.rawValue)
    }
    
    // 判断某个位置是否已绑定
    func isBound(at position: BodyPosition) -> Bool {
        return (bindingState & (1 << position.rawValue)) != 0
    }
    
    // 获取某个位置已绑定的设备
    func getDevice(at position: BodyPosition) -> SensorDeviceProtocol? {
        return deviceMap[position] ?? nil
    }
    
    func checkSensorLocation(at sensorLocation: Int, in deviceName: [SensorType]) -> Bool {
        for pos in BodyPosition.allCases {
            if (sensorLocation & (1 << pos.rawValue)) != 0 {
                guard let dev = getDevice(at: pos), deviceName.contains(where: { $0.rawValue == dev.deviceName }) else {
                    return false
                }
            }
        }
        return true
    }
    
    // 激活WCSession
    func activateWCSession() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        } else {
            Logger.competition.notice_public("WCSession not supported")
        }
    }
    
    // 检测是否有可用的AW
    func existAvailableAW() -> Bool {
        let session = WCSession.default
        if session.activationState != .activated {
            //print("重新激活")
            session.activate()
        }
        if !session.isPaired {
            //print("not paired")
            return false
        }
        return true
    }
    
    // AW只能支持绑定一块（与iphone配对的AW）
    func hasAppleWatchBound() -> Bool {
        for pos in BodyPosition.allCases {
            if let dev = getDevice(at: pos), dev.deviceName == "applewatch" {
                return true
            }
        }
        return false
    }
    
    // 用来卸载卡牌时清理状态
    func resetAllDeviceStatus() {
        for pos in BodyPosition.allCases {
            if var dev = getDevice(at: pos) {
                dev.enableIMU = false
            }
        }
    }
}

extension DeviceManager: WCSessionDelegate {
    func sessionDidBecomeInactive(_ session: WCSession) {
        Logger.competition.notice_public("[DeviceManager] sessionDidBecomeInactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        Logger.competition.notice_public("[DeviceManager] sessionDidDeactivate")
        session.activate()
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Logger.competition.notice_public("[DeviceManager] activationState: \(activationState.rawValue)")
    }
}
