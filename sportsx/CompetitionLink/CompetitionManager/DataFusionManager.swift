//
//  DataFusionManager.swift
//  sportsx
//
//  Created by 任杰 on 2024/12/11.
//

import Foundation
import Combine
import os

// 存储一个[0..windowLen]用于预测的快照
struct DataSnapshot {
    let phoneSlice: [PhoneData?]             // 手机数据切片
    let sensorSlice: [[SensorTrainingData?]] // 传感器二维切片
    let predictTime: Int                     // 此次预测执行的次数
}

class DataFusionManager: ObservableObject {
    static let shared = DataFusionManager()
    
    // 比赛进行的原始时间（秒）
    @Published var elapsedTime: TimeInterval = 0
    // 监测是否到达最大延迟
    @Published var isDelayed: Bool = false
    // 监测各数组的稀疏度
    // [ phone | LH | RH | LF | RF | WAIST ]
    var sparsity: [Float] = [0,0,0,0,0,0]
    
    private var phoneWindow: [PhoneData?] = []
    private var sensorPhoneWindow: [SensorTrainingData?] = []
    private var sensorWindows: [[SensorTrainingData?]] = []
    
    let sensorDeviceCount = 5
    
    // |       deviceNeedToWork       |
    // | 00   +   +   +   +   +    +  |
    //        |   |   |   |   |    |
    //       WST  RF  LF  RH  LH  PHONE
    var deviceNeedToWork: Int = 0b000000
    
    // 待预测的model里最大Input窗口尺寸
    private var maxPredictWindow = 0
    // 允许数组间最大延迟为3s
    private let delayThreshold = 60
    private var phoneCapacity = 0
    private var sensorCapacity = 0
    private let timeStep: TimeInterval = 0.05
    private var baseTime: Date? = nil
    
    // 所有数据序列的起始SlotIndex，用于添加数据时确定位置
    private var startSlotIndex: Int = 0
    
    private let dataCollectQueue = DispatchQueue(label: "com.sportsx.competition.dataCollectQueue", qos: .userInitiated) // 串行队列，用于收集数据
    // 使用 PassthroughSubject 发布数据变化
    let predictionSubject = PassthroughSubject<DataSnapshot, Never>()
    
    
    
    private init() {
        // 初始化空数组
        phoneWindow = Array(repeating: nil, count: phoneCapacity)
        sensorPhoneWindow = Array(repeating: nil, count: phoneCapacity)
        
        sensorWindows = Array(
            repeating: Array(repeating: nil, count: sensorCapacity),
            count: sensorDeviceCount
        )
    }
    
    func setPredictWindow(maxWindow: Int) {
        if maxWindow > maxPredictWindow {
            maxPredictWindow = maxWindow
            phoneCapacity = maxPredictWindow + delayThreshold
            sensorCapacity = phoneCapacity
            
            phoneWindow = Array(repeating: nil, count: phoneCapacity)
            sensorPhoneWindow = Array(repeating: nil, count: phoneCapacity)
            
            sensorWindows = Array(
                repeating: Array(repeating: nil, count: sensorCapacity),
                count: sensorDeviceCount
            )
        }
    }
    
    // 添加手机数据
    func addPhoneData(_ data: PhoneData) {
        dataCollectQueue.async {
            if self.baseTime == nil {
                self.baseTime = data.timestamp
            }
            
            let slotIndex = self.computeSlotIndex(for: data.timestamp)
            let newIndex = self.storePhoneData(data, slotIndex: slotIndex)
            
            if newIndex == -1 { return }
            
            // 更新稀疏度
            let nonNilCount = self.sensorPhoneWindow.filter { $0 != nil }.count
            let lastNonNilIndex = self.lastNonNilIndex(in: self.sensorPhoneWindow)
            //print("phone nonNilCnt: ", nonNilCount, "lastNonNilIndex: ", lastNonNilIndex)
            self.sparsity[0] = nonNilCount == 0 ? 0 : Float(nonNilCount) / Float(lastNonNilIndex + 1)
            
            let windowLen = self.getPredictWindowLen()
            
            // 发布预测信号
            if windowLen >= 0 && windowLen == self.lastNonNilIndex(in: self.sensorPhoneWindow) {
                let snapshot = self.makeSnapshot(upTo: windowLen, time: 1)
                // 发布快照
                self.predictionSubject.send(snapshot)
                Logger.competition.notice_public("sparsity: \(self.sparsity) from addPhoneData")
            }
        }
    }
    
    // 添加传感器设备数据
    func addSensorData(_ sensorIndex: Int, _ batch: [SensorData]) {
        dataCollectQueue.async {
            if self.baseTime == nil {
                Logger.competition.notice_public("baseTime is nil from addSensorData")
                for item in batch {
                    Logger.competition.notice_public("first batch timestamp : \(item.timestamp)")
                }
                let zone = NSTimeZone.system
                let timeInterval = zone.secondsFromGMT()
                let dateNow = Date().addingTimeInterval(TimeInterval(timeInterval))
                self.baseTime = dateNow
                Logger.competition.notice_public("set baseTime to: \(dateNow)")
            }
            
            var shiftSum: Int = 0
            let preWindowLen = self.getPredictWindowLen()
            let isMinWindowOnly = self.isMinWindowOnly(index: sensorIndex)
            
            for item in batch {
                let slotIndex = self.computeSlotIndex(for: item.timestamp)
                let storeResult = self.storeSensorData(item, slotIndex: slotIndex, sensorIndex: sensorIndex)
                shiftSum += storeResult.shiftCount
            }
            
            // 更新稀疏度
            let nonNilCount = self.sensorWindows[sensorIndex].filter { $0 != nil }.count
            let lastNonNilIndex = self.lastNonNilIndex(in: self.sensorWindows[sensorIndex])
            self.sparsity[sensorIndex + 1] = nonNilCount == 0 ? 0 : Float(nonNilCount) / Float(lastNonNilIndex + 1)
            
            let windowLen = self.getPredictWindowLen()
            
            // 需要预测 predictTime 次
            let predictTime = windowLen + shiftSum - preWindowLen
            
            //Logger.competition.notice_public("phonecapacity: \(self.phoneCapacity) sensorCapacity: \(self.sensorCapacity)")
            //Logger.competition.notice_public("sparsity: \(self.sparsity) from addSensorData")
            //Logger.competition.notice_public("windowLen: \(windowLen) predictTime: \(predictTime) isMinWindowOnly: \(isMinWindowOnly)")
            // 发布预测信号
            if windowLen >= 0 && isMinWindowOnly {
                let snapshot = self.makeSnapshot(upTo: windowLen, time: predictTime)
                //Logger.competition.notice_public("windowlen: \(windowLen)")
                // 发布快照
                self.predictionSubject.send(snapshot)
                //Logger.competition.notice_public("sparsity: \(self.sparsity) from addSensorData")
            }
        }
    }
    
    // 判断该sensor是否是最小可用window，且唯一
    private func isMinWindowOnly(index: Int) -> Bool {
        guard index >= 0 && index < sensorDeviceCount else {
            return false
        }
        var lastList: [Int] = []
        let isPhone = deviceNeedToWork & 0b000001 != 0
        let sensors = deviceNeedToWork >> 1

        if isPhone {
            // 找到 phoneWindow & sensorPhoneWindow 的最后一个非nil下标
            lastList.append(lastNonNilIndex(in: sensorPhoneWindow))
        }
        
        for sIndex in 0..<sensorDeviceCount {
            if (sensors & (1 << sIndex)) != 0 && sIndex != index {
                lastList.append(lastNonNilIndex(in: sensorWindows[sIndex]))
            }
        }
        
        // 获取当前下标的待比较元素
        let element = lastNonNilIndex(in: sensorWindows[index])
            
        // 遍历数组，检查是否有其他元素小于该元素
        for i in 0..<lastList.count {
            if lastList[i] <= element {
                return false // 如果有元素小于等于当前元素，返回 false
            }
        }
        return true
    }
    
    private func storePhoneData(_ data: PhoneData, slotIndex: Int) -> Int {
        let sensorTrainingData = SensorTrainingData(
            accX: data.accX,
            accY: data.accY,
            accZ: data.accZ,
            gyroX: data.gyroX,
            gyroY: data.gyroY,
            gyroZ: data.gyroZ
            //magX: data.magX,
            //magY: data.magY,
            //magZ: data.magZ
        )
        
        let arrayIndex = slotIndex - startSlotIndex
        
        // 如果比窗口最早还要早 => 丢弃
        if arrayIndex < 0 {
            return -1
        }
        
        // 如果超出手机数组末尾 => shift
        if arrayIndex >= phoneCapacity {
            let shiftCount = arrayIndex - (phoneCapacity - 1)
            shiftWindow(by: shiftCount)
        }
        
        let newIndex = slotIndex - startSlotIndex
        if newIndex >= 0 && newIndex < phoneCapacity {
            phoneWindow[newIndex] = data
            sensorPhoneWindow[newIndex] = sensorTrainingData
        }
        return newIndex
    }
    
    private func storeSensorData(_ data: SensorData, slotIndex: Int, sensorIndex: Int) -> (newIndex: Int, shiftCount: Int) {
        let sensorTrainingData = SensorTrainingData(
            accX: data.accX,
            accY: data.accY,
            accZ: data.accZ,
            gyroX: data.gyroX,
            gyroY: data.gyroY,
            gyroZ: data.gyroZ
            //magX: data.magX,
            //magY: data.magY,
            //magZ: data.magZ
        )
        
        let arrayIndex = slotIndex - startSlotIndex
        if arrayIndex < 0 {
            // 太旧 => 丢弃
            return (-1, 0)
        }
        var shiftCount = 0
        if arrayIndex >= sensorCapacity {
            // 超出外设数组末尾 => shift
            shiftCount = arrayIndex - (sensorCapacity - 1)
            shiftWindow(by: shiftCount)
        }
        
        let newIndex = slotIndex - startSlotIndex
        if newIndex >= 0 && newIndex < sensorCapacity {
            sensorWindows[sensorIndex][newIndex] = sensorTrainingData
        }
        
        return (newIndex, shiftCount)
    }
    
    // 检查各数据的延迟是否到达阈值
    private func checkDelay() -> Bool {
        let isPhone = deviceNeedToWork & 0b000001 != 0
        let sensors = deviceNeedToWork >> 1

        if isPhone {
            let phoneLast = lastNonNilIndex(in: sensorPhoneWindow)
            if phoneLast < maxPredictWindow - 1 {
                return true
            }
        }

        for sIndex in 0..<sensorDeviceCount {
            if (sensors & (1 << sIndex)) != 0 {
                let sensorLast = lastNonNilIndex(in: sensorWindows[sIndex])
                if sensorLast < maxPredictWindow - 1 {
                    return true
                }
            }
        }
        return false
    }
    
    // predictWindowLen = 所有工作数组中“最后一个非nil下标”的最小值
    // 表示所有数组至少完整覆盖到此下标
    private func getPredictWindowLen() -> Int {
        let isPhone = deviceNeedToWork & 0b000001 != 0
        let sensors = deviceNeedToWork >> 1
        
        // 找到每个外设的最后一个非nil下标
        var lastList: [Int] = []

        if isPhone {
            // 找到 phoneWindow & sensorPhoneWindow 的最后一个非nil下标
            lastList.append(lastNonNilIndex(in: sensorPhoneWindow))
        }

        for sIndex in 0..<sensorDeviceCount {
            if (sensors & (1 << sIndex)) != 0 {
                lastList.append(lastNonNilIndex(in: sensorWindows[sIndex]))
            }
        }
        
        // 在这些最后下标中取最小
        let minSensorLast = lastList.min() ?? -1
        if minSensorLast < 0 {
            // 如果有任何一个设备没有数据，则windowLen = -1表示无
            return -1
        }

        return minSensorLast
    }
    
    // 找到给定数组中最后一个非nil元素的下标；若全nil，则返回-1
    private func lastNonNilIndex(in array: [SensorTrainingData?]) -> Int {
        for i in stride(from: array.count - 1, through: 0, by: -1) {
            if array[i] != nil {
                return i
            }
        }
        return -1
    }
    
    // 制作[0..windowLen] 区间内的所有手机+外设数据快照
    private func makeSnapshot(upTo windowLen: Int, time predictTime: Int) -> DataSnapshot {
        // 要拷贝 phoneData[0..windowLen], sensorData[sIndex][0..windowLen]
        // 注意边界检查: windowLen <= phoneCapacity / sensorCapacity
        let clippedLen = min(windowLen, phoneCapacity - 1, sensorCapacity - 1)
        if clippedLen < 0 {
            return DataSnapshot(
                phoneSlice: [],
                sensorSlice: [],
                predictTime: -1
            )
        }
        let endIndex = clippedLen
        
        // 复制手机数据
        let phoneSlice = Array(phoneWindow[0...endIndex]) // swift中[endIndex]是闭区间
        let sensorPhoneSlice = Array(sensorPhoneWindow[0...endIndex])
        
        // 复制外设二维
        var sensorSlice: [[SensorTrainingData?]] = []
        sensorSlice.append(sensorPhoneSlice)
        for sIndex in 0..<sensorDeviceCount {
            let row = Array(sensorWindows[sIndex][0...endIndex])
            sensorSlice.append(row)
        }
        
        return DataSnapshot(
            phoneSlice: phoneSlice,
            sensorSlice: sensorSlice,
            predictTime: predictTime
        )
    }
    
    private func shiftWindow(by shiftCount: Int) {
        guard shiftCount > 0 else { return }
        
        // 检查数据 delay 情况
        let delayStatus = checkDelay()
        DispatchQueue.main.async {
            self.isDelayed = delayStatus
        }
        
        // 1) shift phoneData
        if shiftCount >= phoneCapacity {
            // 说明新数据比窗口末尾都远 => 整个窗口都过时，直接清空
            phoneWindow = Array(repeating: nil, count: phoneCapacity)
            sensorPhoneWindow = Array(repeating: nil, count: phoneCapacity)
        } else {
            // 把旧的往前搬移
            for i in 0..<(phoneCapacity - shiftCount) {
                phoneWindow[i] = phoneWindow[i + shiftCount]
                sensorPhoneWindow[i] = sensorPhoneWindow[i + shiftCount]
            }
            // 腾出的尾部置空
            for i in (phoneCapacity - shiftCount)..<phoneCapacity {
                phoneWindow[i] = nil
                sensorPhoneWindow[i] = nil
            }
        }
        
        // 2) shift each sensor array
        for sIndex in 0..<sensorDeviceCount {
            let cap = sensorCapacity
            if shiftCount >= cap {
                // 直接清空
                sensorWindows[sIndex] = Array(repeating: nil, count: cap)
                continue
            }
            var arr = sensorWindows[sIndex]
            for i in 0..<(cap - shiftCount) {
                arr[i] = arr[i + shiftCount]
            }
            for i in (cap - shiftCount)..<cap {
                arr[i] = nil
            }
            sensorWindows[sIndex] = arr
        }
        
        // 3) 更新全局startSlotIndex
        startSlotIndex += shiftCount
    }
    
    private func computeSlotIndex(for time: Date) -> Int {
        guard let base = baseTime else { return 0 }
        let delta = time.timeIntervalSince(base)
        let idx = Int(floor(delta / timeStep))
        return max(idx, 0)
    }
    
    func resetAll() {
        maxPredictWindow = 0
        phoneCapacity = 0
        sensorCapacity = 0
        elapsedTime = 0
        sparsity = Array(repeating: 0, count: 6)
        deviceNeedToWork = 0
        startSlotIndex = 0
        baseTime = nil
        phoneWindow = Array(repeating: nil, count: phoneCapacity)
        sensorPhoneWindow = Array(repeating: nil, count: phoneCapacity)
        for sIndex in 0..<sensorDeviceCount {
            sensorWindows[sIndex] = Array(repeating: nil, count: sensorCapacity)
        }
    }
    
    // 返回手机端原始最新待预测数据
    static func getLastPhoneSamples(count: Int, data: [PhoneData?], before: Int) -> [Float] {
        let total = data.count - before
        let startIndex = max(total - count, 0)
        let recentData = Array(data[startIndex..<total])
        let recentDataFloat = convertPhoneToFloatArray(phoneData: recentData)
        
        return recentDataFloat
    }
    
    // 返回多设备端传感器最新待预测数据并预处理
    static func getLastSensorSamples(sensorLocation: Int, count: Int, data: [[SensorTrainingData?]], before: Int) -> [Float] {
        var result: [SensorTrainingData?] = []
        let deviceNum = DataFusionManager.shared.sensorDeviceCount
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
    
    static func convertPhoneToFloatArray(phoneData: [PhoneData?]) -> [Float] {
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
    
    static func convertSensorToFloatArray(sensorData: [SensorTrainingData?]) -> [Float] {
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
}


