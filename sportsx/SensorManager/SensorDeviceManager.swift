//
//  SensorDeviceManager.swift
//  sportsx
//
//  Created by 任杰 on 2025/1/9.
//

import Foundation

enum BodyPosition: Int, CaseIterable {
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
    var isConnected: Bool { get }
    
    // 连接设备
    func connect() -> Bool
    
    // 断开连接
    func disconnect()
    
    // 开始采集
    func startCollection()
    
    // 停止采集
    func stopCollection()
    
    // 这里可以定义一个数据流或者回调，供外部拿到实时数据
    // 例如使用 Combine, 也可以定义 delegate/callback
    //var dataPublisher: Published<[SensorData]>.Publisher { get }
    
    // 如果需要一次性读数据，也可以定义： func fetchLatestData() -> SensorData?
}

// DeviceManager负责管理传感器设备
class DeviceManager: ObservableObject {
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
    
    private init() {}
    
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
    
    // 开始比赛：对已绑定的设备先连接再 startCollection
    /*func startCompetition() {
        for pos in BodyPosition.allCases {
            if let dev = deviceMap[pos], dev != nil {
                dev?.connect { success in
                    if success {
                        dev?.startCollection()
                    }
                }
            }
        }
    }
    
    // 停止比赛：对已绑定设备 stopCollection 并可选择是否断开
    func stopCompetition() {
        for pos in BodyPosition.allCases {
            if let dev = deviceMap[pos], dev != nil {
                dev?.stopCollection()
            }
        }
    }*/
}
