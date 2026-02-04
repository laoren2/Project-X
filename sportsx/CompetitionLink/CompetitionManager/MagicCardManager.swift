//
//  MagicCardManager.swift
//  sportsx
//
//  Created by 任杰 on 2024/12/26.
//

import Foundation
import WatchConnectivity


enum MagicCardFactoryError: LocalizedError {
    case effectNotRegistered(defID: String)
    
    var errorDescription: String? {
        switch self {
        case .effectNotRegistered(let defID):
            return "未找到卡牌定义"
        }
    }
}

class MagicCardFactory {
    typealias CardConstructor = (String, Int, JSONValue) -> MagicCardEffect
    private static var registry: [String: CardConstructor] = [:]
    
    static func register(defID: String, constructor: @escaping CardConstructor) {
        registry[defID] = constructor
    }
    
    static func createEffect(level: Int, from definition: MagicCardDef) throws -> MagicCardEffect {
        guard let constructor = registry[definition.defID] else {
            throw MagicCardFactoryError.effectNotRegistered(defID: definition.defID)
        }
        return constructor(definition.cardID, level, definition.params)
    }
}

protocol MagicCardEffect {
    var cardID: String { get }
    var level: Int { get }
    var params: JSONValue { get }
    func register(eventBus: MatchEventBus)
    func load() async -> Bool
}

extension MagicCardEffect {
    func load() async -> Bool {
        // 默认什么都不做
        return true
    }
}

class EmptyCardEffect:  MagicCardEffect {
    let cardID: String = "empty"
    let level: Int = 0
    let params: JSONValue = .null
    func register(eventBus: MatchEventBus) {}
}

// 基础 bike 校验卡牌
class BikeValidationEffect: MagicCardEffect {
    let cardID: String = "bikeValidationEffect"
    let level: Int = 0
    let params: JSONValue = .null
    
    let window: Int = 60                // 3s
    var remainingSamples: Int = 60      // 3s
    
    private let accFilter = IMUFilter(highPassCutoff: 0.3, sampleRate: 20.0)
    private let gyroFilter = IMUFilter(highPassCutoff: 0.3, sampleRate: 20.0)
    
    func register(eventBus: MatchEventBus) {
        eventBus.on(.matchIMUSensorUpdate) { context in
            let data = context.sensorData
            for i in 0..<data.predictTime {
                self.remainingSamples -= 1
                if self.remainingSamples <= 0 {
                    // 到达预测时机
                    let lastToEnd = data.predictTime - i - 1
                    let total = data.phoneSlice.count - lastToEnd
                    // 数据不足时跳过此次预测
                    if total >= self.window {
                        let startIndex = max(total - self.window, 0)
                        let inputData = Array(data.phoneSlice[startIndex..<total])
                        let result = self.computePedalCounts(with: inputData)
                        context.estimatePedal = result
                    }
                    self.remainingSamples = self.window
                }
            }
        }
    }
    
    func load() async -> Bool {
        CompetitionManager.shared.sensorRequest |= 1
        DataFusionManager.shared.setPredictWindow(maxWindow: window)
        return true
    }
    
    func computePedalCounts(with samples: [PhoneData?]) -> Double {
        // 完成踏频预测
        guard samples.count == 60 else { return 0 }
        
        // 对samples中的nil元素进行平滑差值替换
        var final_samples: [PhoneData] = []
        for (index, sample) in samples.enumerated() {
            if let valid = sample {
                final_samples.append(valid)
            } else {
                // 向前寻找最近的非nil
                let prev = samples[..<index].last(where: { $0 != nil }) ?? samples.first ?? nil
                // 向后寻找最近的非nil
                let next = samples[index...].first(where: { $0 != nil }) ?? samples.last ?? nil
                if let p = prev, let n = next {
                    // 时间比例线性插值
                    let t1 = p.timestamp
                    let t2 = n.timestamp
                    let ratio = (samples[index]?.timestamp ?? ((t1 + t2) / 2) - t1) / max(t2 - t1, 0.0001)
                    let interp = PhoneData(
                        timestamp: (t1 + t2) / 2,
                        altitude: p.altitude + (n.altitude - p.altitude) * ratio,
                        speed: p.speed + (n.speed - p.speed) * ratio,
                        accX: p.accX + (n.accX - p.accX) * ratio,
                        accY: p.accY + (n.accY - p.accY) * ratio,
                        accZ: p.accZ + (n.accZ - p.accZ) * ratio,
                        gyroX: p.gyroX + (n.gyroX - p.gyroX) * ratio,
                        gyroY: p.gyroY + (n.gyroY - p.gyroY) * ratio,
                        gyroZ: p.gyroZ + (n.gyroZ - p.gyroZ) * ratio,
                        magX: p.magX + (n.magX - p.magX) * ratio,
                        magY: p.magY + (n.magY - p.magY) * ratio,
                        magZ: p.magZ + (n.magZ - p.magZ) * ratio,
                        audioSample: false
                    )
                    final_samples.append(interp)
                } else if let p = prev {
                    final_samples.append(p)
                } else if let n = next {
                    final_samples.append(n)
                } else {
                    continue
                }
            }
        }
        
        let accData: [(Double, TimeInterval)] = final_samples.map {
            return (accFilter.filteredSamples(x: $0.accX, y: $0.accY, z: $0.accZ), $0.timestamp)
        }
        let gyroData: [(Double, TimeInterval)] = final_samples.map {
            return (gyroFilter.filteredSamples(x: $0.gyroX, y: $0.gyroY, z: $0.gyroZ), $0.timestamp)
        }
        
        // 检测极小值 + 记录 acc 极小值左右的极大值
        struct AccValley {
            let value: Double
            let time: TimeInterval
            let leftPeak: Double
            let rightPeak: Double
        }
        
        var accValleys: [(Double, TimeInterval)] = []
        var gyroValleys: [(Double, TimeInterval)] = []
        // 待选的极小值点
        var accValidValleys: [AccValley] = []
        
        // 原始极小值统计
        for i in 1..<accData.count-1 {
            // acc 极小值
            if accData[i].0 < accData[i-1].0 && accData[i].0 < accData[i+1].0 {
                var leftCount = 0
                var leftDiff = 0.0
                for l in stride(from: i - 1, through: 0, by: -1) {
                    if accData[l].0 > accData[l+1].0 {
                        leftCount += 1
                        leftDiff += accData[l].0 - accData[l+1].0
                    } else {
                        break
                    }
                }

                var rightCount = 0
                var rightDiff = 0.0
                for r in i + 1..<accData.count {
                    if accData[r].0 > accData[r - 1].0 {
                        rightCount += 1
                        rightDiff += accData[r].0 - accData[r-1].0
                    } else {
                        break
                    }
                }
                accValleys.append(accData[i])
                if leftCount >= 3 && leftCount <= 13 && rightCount >= 3 && rightCount <= 13 && leftDiff > 0.1 && rightDiff > 0.1 {
                    accValidValleys.append(
                        AccValley(
                            value: accData[i].0,
                            time: accData[i].1,
                            leftPeak: accData[i].0 + leftDiff,
                            rightPeak: accData[i].0 + rightDiff
                        )
                    )
                }
            }
            // gyro 极小值
            if gyroData[i].0 < gyroData[i-1].0 && gyroData[i].0 < gyroData[i+1].0 {
                gyroValleys.append((gyroData[i].0, gyroData[i].1))
            }
        }
        
        if accValidValleys.count < 2 { return 0 }
        
        // 遍历 acc 极小值两两组合，寻找旋转周期
        var cycleDurations: [Double] = []
        let timeTolerance: TimeInterval = 0.2
        
        for i in 0..<accValidValleys.count-1 {
            let a1 = accValidValleys[i]
            let a2 = accValidValleys[i+1]
            
            if a2.time - a1.time < 0.4 || a2.time - a1.time > 2 { continue }
            
            // 在 acc1 - acc2 之间求所有极小值时间的平均值 t
            let mids = accValleys.filter { $0.1 >= a1.time && $0.1 <= a2.time }
            let t = mids.map{$0.1}.reduce(0, +) / Double(mids.count)
            
            // 检查是否存在 gyro 极小值落在 t 的 ±0.2s 内
            let gyroMatched = gyroValleys.contains(where: { abs($0.1 - t) <= timeTolerance })
            if !gyroMatched { continue }
            
            // acc1 右侧极大值 < acc2 左侧极大值
            if a1.rightPeak < a2.leftPeak {
                let period = a2.time - a1.time
                if period > 0 {
                    cycleDurations.append(period)
                }
            }
        }
        
        guard cycleDurations.count > 0 else { return 0 }
        
        let avgPeriod = cycleDurations.reduce(0,+) / Double(cycleDurations.count)
        
        // 计算踏频（RPM）：3 秒内的平均脚踏转速 = 60 / 周期
        let rpm = 60.0 / avgPeriod
        return rpm
    }
}

// 基础 running 校验卡牌
// todo: 目前颗粒度过粗，可优化为结束时统计全局数据并计算每个 pathpoint 对应的窗口（如10s）内的平均步频
class RunningValidationEffect: MagicCardEffect {
    let cardID: String = "runningValidationEffect"
    let level: Int = 0
    let params: JSONValue = .null
    
    let window: Int = 60                // 3s
    var remainingSamples: Int = 60      // 3s
    private let magFilter = IMUFilter(highPassCutoff: 0.3, sampleRate: 20.0)
    private let accFilter = IMUFilter(highPassCutoff: 0.3, sampleRate: 20.0)
    private let gyroFilter = IMUFilter(highPassCutoff: 0.3, sampleRate: 20.0)
    private let accThreshold = 0.2
    private let gyroThreshold = 0.5
    
    func register(eventBus: MatchEventBus) {
        eventBus.on(.matchIMUSensorUpdate) { context in
            //print("on matchIMUSensorUpdate")
            let data = context.sensorData
            for i in 0..<data.predictTime {
                self.remainingSamples -= 1
                if self.remainingSamples <= 0 {
                    // 到达预测时机
                    let lastToEnd = data.predictTime - i - 1
                    let total = data.phoneSlice.count - lastToEnd
                    // 数据不足时跳过此次预测
                    if total >= self.window {
                        let startIndex = max(total - self.window, 0)
                        let inputData = Array(data.phoneSlice[startIndex..<total])
                        let result = self.computeStepCounts(with: inputData)
                        context.estimateStep = result.0
                        //context.stepCadence = result.1
                    }
                    self.remainingSamples = self.window
                }
            }
        }
    }
    
    func load() async -> Bool {
        CompetitionManager.shared.sensorRequest |= 1
        DataFusionManager.shared.setPredictWindow(maxWindow: window)
        return true
    }
    
    func computeStepCounts(with samples: [PhoneData?]) -> (Double, Double) {
        guard samples.count == 60 else { return (0, 0) }

        // 对samples中的nil元素进行平滑差值替换
        var final_samples: [PhoneData] = []
        for (index, sample) in samples.enumerated() {
            if let valid = sample {
                final_samples.append(valid)
            } else {
                // 向前寻找最近的非nil
                let prev = samples[..<index].last(where: { $0 != nil }) ?? samples.first ?? nil
                // 向后寻找最近的非nil
                let next = samples[index...].first(where: { $0 != nil }) ?? samples.last ?? nil
                if let p = prev, let n = next {
                    // 时间比例线性插值
                    let t1 = p.timestamp
                    let t2 = n.timestamp
                    let ratio = (samples[index]?.timestamp ?? ((t1 + t2) / 2) - t1) / max(t2 - t1, 0.0001)
                    let interp = PhoneData(
                        timestamp: (t1 + t2) / 2,
                        altitude: p.altitude + (n.altitude - p.altitude) * ratio,
                        speed: p.speed + (n.speed - p.speed) * ratio,
                        accX: p.accX + (n.accX - p.accX) * ratio,
                        accY: p.accY + (n.accY - p.accY) * ratio,
                        accZ: p.accZ + (n.accZ - p.accZ) * ratio,
                        gyroX: p.gyroX + (n.gyroX - p.gyroX) * ratio,
                        gyroY: p.gyroY + (n.gyroY - p.gyroY) * ratio,
                        gyroZ: p.gyroZ + (n.gyroZ - p.gyroZ) * ratio,
                        magX: p.magX + (n.magX - p.magX) * ratio,
                        magY: p.magY + (n.magY - p.magY) * ratio,
                        magZ: p.magZ + (n.magZ - p.magZ) * ratio,
                        audioSample: false
                    )
                    final_samples.append(interp)
                } else if let p = prev {
                    final_samples.append(p)
                } else if let n = next {
                    final_samples.append(n)
                } else {
                    continue
                }
            }
        }

        // 1. 滤波
        let magData: [(Double, TimeInterval)] = final_samples.map {
            return (magFilter.filteredSamples(x: $0.magX, y: $0.magY, z: $0.magZ), $0.timestamp)
        }
        let accData: [(Double, TimeInterval)] = final_samples.map {
            return (accFilter.filteredSamples(x: $0.accX, y: $0.accY, z: $0.accZ), $0.timestamp)
        }
        let gyroData: [(Double, TimeInterval)] = final_samples.map {
            return (gyroFilter.filteredSamples(x: $0.gyroX, y: $0.gyroY, z: $0.gyroZ), $0.timestamp)
        }

        // 2. 峰值检测
        var eventCount = 0
        var magPeaks:[(Double, TimeInterval)] = []
        var accPeaks:[(Double, TimeInterval)] = []
        var gyroPeaks:[(Double, TimeInterval)] = []

        // 统计符合要求的 magData 峰值
        for i in 1..<magData.count-1 {
            if magData[i].0 > magData[i-1].0 && magData[i].0 > magData[i+1].0 {
                var leftCount = 0
                var leftDiff = 0.0
                for l in stride(from: i - 1, through: 0, by: -1) {
                    if magData[l].0 < magData[l + 1].0 {
                        leftCount += 1
                        leftDiff += magData[l + 1].0 - magData[l].0
                    } else {
                        break
                    }
                }

                var rightCount = 0
                var rightDiff = 0.0
                for r in i + 1..<magData.count {
                    if magData[r].0 < magData[r - 1].0 {
                        rightCount += 1
                        rightDiff += magData[r - 1].0 - magData[r].0
                    } else {
                        break
                    }
                }
                //print("leftCount: \(leftCount) rightCount: \(rightCount)")
                let totalCount = leftCount + rightCount
                if totalCount >= 10 && totalCount <= 40 && (leftDiff > 3 || rightDiff > 3 || (leftDiff + rightDiff) > 5) {
                    magPeaks.append(magData[i])
                }
            }
        }

        // 统计符合要求的 accData 峰值，要求左侧或右侧的单边峰差值大于 accThreshold/2 或两边峰差值之和大于 accThreshold
        for i in 1..<accData.count-1 {
            if accData[i].0 > accData[i-1].0 && accData[i].0 > accData[i+1].0 {
                var leftDiff = 0.0
                for l in stride(from: i - 1, through: 0, by: -1) {
                    if accData[l].0 < accData[l + 1].0 {
                        leftDiff += accData[l + 1].0 - accData[l].0
                    } else {
                        break
                    }
                }
                var rightDiff = 0.0
                for r in i + 1..<accData.count {
                    if accData[r].0 < accData[r - 1].0 {
                        rightDiff += accData[r - 1].0 - accData[r].0
                    } else {
                        break
                    }
                }
                if leftDiff > accThreshold / 2 || rightDiff > accThreshold / 2 || (leftDiff + rightDiff) > accThreshold {
                    accPeaks.append(accData[i])
                }
            }
        }

        // 统计符合要求的 gyroData 峰值，要求左侧或右侧的单边峰差值大于 gyroThreshold/2 或两边峰差值之和大于 gyroThreshold
        for i in 1..<gyroData.count-1 {
            if gyroData[i].0 > gyroData[i-1].0 && gyroData[i].0 > gyroData[i+1].0 {
                var leftDiff = 0.0
                for l in stride(from: i - 1, through: 0, by: -1) {
                    if gyroData[l].0 < gyroData[l + 1].0 {
                        leftDiff += gyroData[l + 1].0 - gyroData[l].0
                    } else {
                        break
                    }
                }
                var rightDiff = 0.0
                for r in i + 1..<gyroData.count {
                    if gyroData[r].0 < gyroData[r - 1].0 {
                        rightDiff += gyroData[r - 1].0 - gyroData[r].0
                    } else {
                        break
                    }
                }
                if leftDiff > gyroThreshold / 2 || rightDiff > gyroThreshold / 2 || (leftDiff + rightDiff) > gyroThreshold {
                    gyroPeaks.append(gyroData[i])
                }
            }
        }

        // 综合 accPeaks 和 gyroPeaks ，筛选出合理的 magPeaks，符合要求的 magPeak 应该在 0.2s 的范围内成功寻找到 accPeak 或 gyroPeak
        let timeTolerance: TimeInterval = 0.2
        magPeaks = magPeaks.filter { magPeak in
            return accPeaks.contains(where: { abs($0.1 - magPeak.1) <= timeTolerance }) ||
                   gyroPeaks.contains(where: { abs($0.1 - magPeak.1) <= timeTolerance })
        }

        eventCount = min(2 * magPeaks.count, 12)

        // 3.结合平均步频减少误差
        var step_frequency = 0.0
        if magPeaks.count >= 2 {
            var intervals: [TimeInterval] = []
            for j in 1..<magPeaks.count {
                intervals.append(magPeaks[j].1 - magPeaks[j-1].1)
            }
            let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
            step_frequency = min(120.0 / avgInterval, 240)
            
            let ratio = eventCount > 0 ? step_frequency / (20 * Double(eventCount)) : 0
            //print("magPeaks: \(magPeaks.count) step_count: \(eventCount) freq: \(step_frequency)")
            return (ratio > 2 || ratio < 1/2)
            ? (Double(eventCount), step_frequency)
            : ((Double(eventCount) + step_frequency / 20.0) / 2.0, step_frequency)
        }
        //print("magPeaks: \(magPeaks.count) step_count: \(eventCount) freq: \(step_frequency)")

        return (Double(eventCount), step_frequency)
    }
}

class SpeedEffect_B_00000002: MagicCardEffect {
    let cardID: String
    let level: Int
    let params: JSONValue
    
    let speed_from: Double
    let speed_to: Double
    let bonus_ratio: Double
    let bonus_ratio_member: Double
    let speed_skill1: Double
    let bonus_skill1: Double
    let bonus_member_skill1: Double
    
    init(cardID: String, level: Int, with params: JSONValue) {
        self.cardID = cardID
        self.level = level
        self.params = params
        
        self.speed_from = params["static_values", "speed_from"]?.doubleValue ?? 0
        self.speed_to = params["static_values", "speed_to"]?.doubleValue ?? 0
        
        self.bonus_ratio = params["compute_values", "bonus_ratio"]?.doubleValue ?? 0
        self.bonus_ratio_member = params["compute_values", "bonus_ratio_member"]?.doubleValue ?? 0
        self.speed_skill1 = params["static_values", "speed_skill1"]?.doubleValue ?? 0
        self.bonus_skill1 = params["compute_values", "bonus_skill1"]?.doubleValue ?? 0
        self.bonus_member_skill1 = params["compute_values", "bonus_member_skill1"]?.doubleValue ?? 0
    }
    
    func register(eventBus: MatchEventBus) {
        eventBus.on(.matchStart) { context in
            CompetitionManager.shared.startCompetitionWithTeamBonusCard(cardID: self.cardID)
        }
        eventBus.on(.matchCycleUpdate) { context in
            if context.speed >= self.speed_from && context.speed <= self.speed_to {
                context.addOrUpdateBonus(cardID: self.cardID, bonus: self.bonus_ratio * 0.01 * 3)
                context.addOrUpdateTeamBonusTime(cardID: self.cardID, bonusTime: self.bonus_ratio_member * 0.01 * 3)
            }
        }
        eventBus.on(.matchEnd) { context in
            let speedAvg_kmh = 3.6 * context.distance / DataFusionManager.shared.elapsedTime
            if self.level >= 3 && speedAvg_kmh >= self.speed_skill1 && speedAvg_kmh <= self.speed_to {
                context.addOrUpdateBonus(cardID: self.cardID, bonus: self.bonus_skill1)
                context.addOrUpdateTeamBonusTime(cardID: self.cardID, bonusTime: self.bonus_member_skill1)
            }
        }
    }
}

/*class SpeedEffect_A_00000000: MagicCardEffect {
    let cardID: String
    let level: Int
    let params: JSONValue
    
    init(cardID: String, level: Int, with params: JSONValue) {
        self.cardID = cardID
        self.level = level
        self.params = params
    }
    
    func register(eventBus: MatchEventBus) {
        eventBus.on(.matchStart) { context in
            CompetitionManager.shared.startCompetitionWithTeamBonusCard(cardID: self.cardID)
        }
        eventBus.on(.matchCycleUpdate) { context in
            context.addOrUpdateBonus(cardID: self.cardID, bonus: 0.2)
            context.addOrUpdateTeamBonusTime(cardID: self.cardID, bonusTime: 0.1)
        }
    }
}*/

class SpeedEffect_A_00000002: MagicCardEffect {
    let cardID: String
    let level: Int
    let params: JSONValue
    
    let speed_from: Double
    let speed_to: Double
    
    let bonus_ratio: Double
    let bonus_ratio_member: Double
    let speed_skill1: Double
    let bonus_skill1: Double
    let bonus_member_skill1: Double
    let speed_skill2: Double
    let bonus_skill2: Double
    let bonus_member_skill2: Double
    
    init(cardID: String, level: Int, with params: JSONValue) {
        self.cardID = cardID
        self.level = level
        self.params = params
        
        self.speed_from = params["static_values", "speed_from"]?.doubleValue ?? 0
        self.speed_to = params["static_values", "speed_to"]?.doubleValue ?? 0
        
        self.bonus_ratio = params["compute_values", "bonus_ratio"]?.doubleValue ?? 0
        self.bonus_ratio_member = params["compute_values", "bonus_ratio_member"]?.doubleValue ?? 0
        self.speed_skill1 = params["static_values", "speed_skill1"]?.doubleValue ?? 0
        self.bonus_skill1 = params["compute_values", "bonus_skill1"]?.doubleValue ?? 0
        self.bonus_member_skill1 = params["compute_values", "bonus_member_skill1"]?.doubleValue ?? 0
        self.speed_skill2 = params["static_values", "speed_skill2"]?.doubleValue ?? 0
        self.bonus_skill2 = params["compute_values", "bonus_skill2"]?.doubleValue ?? 0
        self.bonus_member_skill2 = params["compute_values", "bonus_member_skill2"]?.doubleValue ?? 0
    }
    
    func register(eventBus: MatchEventBus) {
        eventBus.on(.matchStart) { context in
            CompetitionManager.shared.startCompetitionWithTeamBonusCard(cardID: self.cardID)
        }
        eventBus.on(.matchCycleUpdate) { context in
            if context.speed >= self.speed_from && context.speed <= self.speed_to {
                context.addOrUpdateBonus(cardID: self.cardID, bonus: self.bonus_ratio * 0.01 * 3)
                context.addOrUpdateTeamBonusTime(cardID: self.cardID, bonusTime: self.bonus_ratio_member * 0.01 * 3)
            }
        }
        eventBus.on(.matchEnd) { context in
            let speedAvg_kmh = 3.6 * context.distance / DataFusionManager.shared.elapsedTime
            if self.level >= 3 && speedAvg_kmh >= self.speed_skill1 && speedAvg_kmh <= self.speed_to {
                context.addOrUpdateBonus(cardID: self.cardID, bonus: self.bonus_skill1)
                context.addOrUpdateTeamBonusTime(cardID: self.cardID, bonusTime: self.bonus_member_skill1)
            }
            if self.level >= 6 && speedAvg_kmh >= self.speed_skill2 && speedAvg_kmh <= self.speed_to {
                context.addOrUpdateBonus(cardID: self.cardID, bonus: self.bonus_skill2)
                context.addOrUpdateTeamBonusTime(cardID: self.cardID, bonusTime: self.bonus_member_skill2)
            }
        }
    }
}

class SpeedEffect_B_00000001: MagicCardEffect {
    let cardID: String
    let level: Int
    let params: JSONValue
    
    let speed_from: Double
    let speed_to: Double
    let bonus_ratio: Double
    let bonus_ratio_member: Double
    let speed_skill1: Double
    let bonus_skill1: Double
    let bonus_member_skill1: Double
    
    init(cardID: String, level: Int, with params: JSONValue) {
        self.cardID = cardID
        self.level = level
        self.params = params
        
        let speed_from_min = params["static_values", "speed_from_min"]?.doubleValue ?? 0
        let speed_from_second = params["static_values", "speed_from_second"]?.doubleValue ?? 0
        self.speed_from = speed_from_min + speed_from_second / 60
        let speed_to_min = params["static_values", "speed_to_min"]?.doubleValue ?? 0
        let speed_to_second = params["static_values", "speed_to_second"]?.doubleValue ?? 0
        self.speed_to = speed_to_min + speed_to_second / 60
        
        self.bonus_ratio = params["compute_values", "bonus_ratio"]?.doubleValue ?? 0
        self.bonus_ratio_member = params["compute_values", "bonus_ratio_member"]?.doubleValue ?? 0
        let speed_min_skill1 = params["static_values", "speed_min_skill1"]?.doubleValue ?? 0
        let speed_second_skill1 = params["static_values", "speed_second_skill1"]?.doubleValue ?? 0
        self.speed_skill1 = speed_min_skill1 + speed_second_skill1 / 60
        self.bonus_skill1 = params["compute_values", "bonus_skill1"]?.doubleValue ?? 0
        self.bonus_member_skill1 = params["compute_values", "bonus_member_skill1"]?.doubleValue ?? 0
    }
    
    func register(eventBus: MatchEventBus) {
        eventBus.on(.matchStart) { context in
            CompetitionManager.shared.startCompetitionWithTeamBonusCard(cardID: self.cardID)
        }
        eventBus.on(.matchCycleUpdate) { context in
            let speed_minkm = 60.0 / context.speed
            if speed_minkm >= self.speed_from && speed_minkm <= self.speed_to {
                context.addOrUpdateBonus(cardID: self.cardID, bonus: self.bonus_ratio * 0.01 * 3)
                context.addOrUpdateTeamBonusTime(cardID: self.cardID, bonusTime: self.bonus_ratio_member * 0.01 * 3)
            }
        }
        eventBus.on(.matchEnd) { context in
            let speedAvg_kmh = 3.6 * context.distance / DataFusionManager.shared.elapsedTime
            let speedAvg_minkm = 60.0 / speedAvg_kmh
            if self.level >= 3 && speedAvg_minkm >= self.speed_from && speedAvg_minkm <= self.speed_skill1 {
                context.addOrUpdateBonus(cardID: self.cardID, bonus: self.bonus_skill1)
                context.addOrUpdateTeamBonusTime(cardID: self.cardID, bonusTime: self.bonus_member_skill1)
            }
        }
    }
}

class SpeedEffect_A_00000001: MagicCardEffect {
    let cardID: String
    let level: Int
    let params: JSONValue
    
    let speed_from: Double
    let speed_to: Double
    
    let bonus_ratio: Double
    let bonus_ratio_member: Double
    let speed_skill1: Double
    let bonus_skill1: Double
    let bonus_member_skill1: Double
    let speed_skill2: Double
    let bonus_skill2: Double
    let bonus_member_skill2: Double
    
    init(cardID: String, level: Int, with params: JSONValue) {
        self.cardID = cardID
        self.level = level
        self.params = params
        
        let speed_from_min = params["static_values", "speed_from_min"]?.doubleValue ?? 0
        let speed_from_second = params["static_values", "speed_from_second"]?.doubleValue ?? 0
        self.speed_from = speed_from_min + speed_from_second / 60
        let speed_to_min = params["static_values", "speed_to_min"]?.doubleValue ?? 0
        let speed_to_second = params["static_values", "speed_to_second"]?.doubleValue ?? 0
        self.speed_to = speed_to_min + speed_to_second / 60
        
        self.bonus_ratio = params["compute_values", "bonus_ratio"]?.doubleValue ?? 0
        self.bonus_ratio_member = params["compute_values", "bonus_ratio_member"]?.doubleValue ?? 0
        
        let speed_min_skill1 = params["static_values", "speed_min_skill1"]?.doubleValue ?? 0
        let speed_second_skill1 = params["static_values", "speed_second_skill1"]?.doubleValue ?? 0
        self.speed_skill1 = speed_min_skill1 + speed_second_skill1 / 60
        self.bonus_skill1 = params["compute_values", "bonus_skill1"]?.doubleValue ?? 0
        self.bonus_member_skill1 = params["compute_values", "bonus_member_skill1"]?.doubleValue ?? 0
        
        let speed_min_skill2 = params["static_values", "speed_min_skill2"]?.doubleValue ?? 0
        let speed_second_skill2 = params["static_values", "speed_second_skill2"]?.doubleValue ?? 0
        self.speed_skill2 = speed_min_skill2 + speed_second_skill2 / 60
        self.bonus_skill2 = params["compute_values", "bonus_skill2"]?.doubleValue ?? 0
        self.bonus_member_skill2 = params["compute_values", "bonus_member_skill2"]?.doubleValue ?? 0
    }
    
    func register(eventBus: MatchEventBus) {
        eventBus.on(.matchStart) { context in
            CompetitionManager.shared.startCompetitionWithTeamBonusCard(cardID: self.cardID)
        }
        eventBus.on(.matchCycleUpdate) { context in
            let speed_minkm = 60.0 / context.speed
            if speed_minkm >= self.speed_from && speed_minkm <= self.speed_to {
                context.addOrUpdateBonus(cardID: self.cardID, bonus: self.bonus_ratio * 0.01 * 3)
                context.addOrUpdateTeamBonusTime(cardID: self.cardID, bonusTime: self.bonus_ratio_member * 0.01 * 3)
            }
        }
        eventBus.on(.matchEnd) { context in
            let speedAvg_kmh = 3.6 * context.distance / DataFusionManager.shared.elapsedTime
            let speedAvg_minkm = 60.0 / speedAvg_kmh
            if self.level >= 3 && speedAvg_minkm >= self.speed_from && speedAvg_minkm <= self.speed_skill1 {
                context.addOrUpdateBonus(cardID: self.cardID, bonus: self.bonus_skill1)
                context.addOrUpdateTeamBonusTime(cardID: self.cardID, bonusTime: self.bonus_member_skill1)
            }
            if self.level >= 6 && speedAvg_minkm >= self.speed_from && speedAvg_minkm <= self.speed_skill2 {
                context.addOrUpdateBonus(cardID: self.cardID, bonus: self.bonus_skill2)
                context.addOrUpdateTeamBonusTime(cardID: self.cardID, bonusTime: self.bonus_member_skill2)
            }
        }
    }
}

class AltitudeEffect_C_00000001: MagicCardEffect {
    let cardID: String
    let level: Int
    let params: JSONValue
    
    let bonus_ratio: Double
    var last_altitude: Double = 0
    
    init(cardID: String, level: Int, with params: JSONValue) {
        self.cardID = cardID
        self.level = level
        self.params = params
        self.bonus_ratio = params["compute_values", "bonus_ratio"]?.doubleValue ?? 0
    }
    
    func register(eventBus: MatchEventBus) {
        eventBus.on(.matchCycleUpdate) { context in
            if context.altitude > self.last_altitude {
                context.addOrUpdateBonus(cardID: self.cardID, bonus: self.bonus_ratio * 0.01 * 3)
            }
            self.last_altitude = context.altitude
        }
    }
}

class AltitudeEffect_B_00000001: MagicCardEffect {
    let cardID: String
    let level: Int
    let params: JSONValue
    
    let bonus_ratio: Double
    let bonus_from_skill1: Double
    let bonus_to_skill1: Double
    let altitude_low: Double
    let altitude_high: Double
    
    var last_altitude: Double = 0
    var cumulative_climb: Double = 0
    
    init(cardID: String, level: Int, with params: JSONValue) {
        self.cardID = cardID
        self.level = level
        self.params = params
        self.bonus_ratio = params["compute_values", "bonus_ratio"]?.doubleValue ?? 0
        self.bonus_from_skill1 = params["compute_values", "bonus_from_skill1"]?.doubleValue ?? 0
        self.bonus_to_skill1 = params["compute_values", "bonus_to_skill1"]?.doubleValue ?? 0
        self.altitude_low = params["static_values", "altitude_low"]?.doubleValue ?? 10
        self.altitude_high = params["static_values", "altitude_high"]?.doubleValue ?? 100
    }
    
    func register(eventBus: MatchEventBus) {
        eventBus.on(.matchCycleUpdate) { context in
            if context.altitude > self.last_altitude {
                let meters = context.altitude - self.last_altitude
                self.cumulative_climb += meters
                context.addOrUpdateBonus(cardID: self.cardID, bonus: self.bonus_ratio * 0.01 * 3)
            }
            self.last_altitude = context.altitude
        }
        eventBus.on(.matchEnd) { context in
            if self.level >= 3 && self.cumulative_climb >= self.altitude_low && self.cumulative_climb <= self.altitude_high {
                let bonus = self.bonus_from_skill1 + (self.bonus_to_skill1 - self.bonus_from_skill1) * (self.cumulative_climb - self.altitude_low) / (self.altitude_high - self.altitude_low)
                context.addOrUpdateBonus(cardID: self.cardID, bonus: bonus)
            }
        }
    }
}

class HeartRateEffect_C_00000001: MagicCardEffect {
    let cardID: String
    let level: Int
    let params: JSONValue
    
    let bonus_ratio: Double
    let heart_rate_low: Double
    let heart_rate_high: Double
    
    init(cardID: String, level: Int, with params: JSONValue) {
        self.cardID = cardID
        self.level = level
        self.params = params
        self.bonus_ratio = params["compute_values", "bonus_ratio"]?.doubleValue ?? 0
        self.heart_rate_low = params["static_values", "heart_rate_low"]?.doubleValue ?? 120
        self.heart_rate_high = params["static_values", "heart_rate_high"]?.doubleValue ?? 160
    }
    
    func load() async -> Bool {
        // 设置真实绑定方案
        var sensorTypes: [SensorType] = []
        if let sensorStrings = params["sensor_type"]?.arrayValue?.compactMap({ $0.stringValue }) {
            sensorTypes = sensorStrings.compactMap { SensorType(rawValue: $0) }
        }
        if let sensorLocation = params["sensor_location"]?.intValue, DeviceManager.shared.checkSensorLocation(at: sensorLocation >> 1, in: sensorTypes) {
            CompetitionManager.shared.sensorRequest |= sensorLocation
            return true
        }
        if let sensorLocation2 = params["sensor_location2"]?.intValue, DeviceManager.shared.checkSensorLocation(at: sensorLocation2 >> 1, in: sensorTypes) {
            CompetitionManager.shared.sensorRequest |= sensorLocation2
            return true
        }
        return false
    }
    
    func register(eventBus: MatchEventBus) {
        eventBus.on(.matchCycleUpdate) { context in
            if let heartRate = context.latestHeartRate, heartRate >= self.heart_rate_low, heartRate <= self.heart_rate_high  {
                context.addOrUpdateBonus(cardID: self.cardID, bonus: 0.01 * self.bonus_ratio * 3)
            }
        }
    }
}

class HeartRateEffect_B_00000001: MagicCardEffect {
    let cardID: String
    let level: Int
    let params: JSONValue
    
    let bonus_ratio: Double
    let aerobic_ratio_skill1: Double
    let bonus_time_skill1: Double
    let bonus_time2_skill1: Double
    let heart_rate_low: Double
    let heart_rate_high: Double
    
    var aerobic_duration: Double = 0
    
    init(cardID: String, level: Int, with params: JSONValue) {
        self.cardID = cardID
        self.level = level
        self.params = params
        self.bonus_ratio = params["compute_values", "bonus_ratio"]?.doubleValue ?? 0
        let aerobic_per_skill1 = params["static_values", "aerobic_ratio_skill1"]?.doubleValue ?? 50
        self.aerobic_ratio_skill1 = 0.01 * aerobic_per_skill1
        self.bonus_time_skill1 = params["compute_values", "bonus_time_skill1"]?.doubleValue ?? 0
        self.bonus_time2_skill1 = params["compute_values", "bonus_time2_skill1"]?.doubleValue ?? 0
        self.heart_rate_low = params["static_values", "heart_rate_low"]?.doubleValue ?? 120
        self.heart_rate_high = params["static_values", "heart_rate_high"]?.doubleValue ?? 160
    }
    
    func load() async -> Bool {
        // 设置真实绑定方案
        var sensorTypes: [SensorType] = []
        if let sensorStrings = params["sensor_type"]?.arrayValue?.compactMap({ $0.stringValue }) {
            sensorTypes = sensorStrings.compactMap { SensorType(rawValue: $0) }
        }
        if let sensorLocation = params["sensor_location"]?.intValue, DeviceManager.shared.checkSensorLocation(at: sensorLocation >> 1, in: sensorTypes) {
            CompetitionManager.shared.sensorRequest |= sensorLocation
            return true
        }
        if let sensorLocation2 = params["sensor_location2"]?.intValue, DeviceManager.shared.checkSensorLocation(at: sensorLocation2 >> 1, in: sensorTypes) {
            CompetitionManager.shared.sensorRequest |= sensorLocation2
            return true
        }
        return false
    }
    
    func register(eventBus: MatchEventBus) {
        eventBus.on(.matchCycleUpdate) { context in
            if let heartRate = context.latestHeartRate, heartRate >= self.heart_rate_low, heartRate <= self.heart_rate_high {
                context.addOrUpdateBonus(cardID: self.cardID, bonus: 0.01 * self.bonus_ratio * 3)
                self.aerobic_duration += 3
            }
        }
        eventBus.on(.matchEnd) { context in
            let aerobic_ratio = self.aerobic_duration /  DataFusionManager.shared.elapsedTime
            if self.level >= 3 && aerobic_ratio >= self.aerobic_ratio_skill1 && aerobic_ratio <= 1 {
                let bonus = (aerobic_ratio - self.aerobic_ratio_skill1) / (1 - self.aerobic_ratio_skill1) * self.bonus_time2_skill1
                context.addOrUpdateBonus(cardID: self.cardID, bonus: bonus)
            }
            if let avgHeartRate = context.avgHeartRate {
                if self.level >= 3 && avgHeartRate >= self.heart_rate_low && avgHeartRate <= self.heart_rate_high {
                    context.addOrUpdateBonus(cardID: self.cardID, bonus: self.bonus_time_skill1)
                }
            }
        }
    }
}

class XposeTestEffect: MagicCardEffect {
    let cardID: String
    let level: Int
    let params: JSONValue
    
    let bonusTime: Double
    let bonusTimeSkill1: Double
    let inputWindowInSamples: Int
    let predictionIntervalInSamples: Int
    
    private let modelKey: String
    private var predictModel: GenericPredictModel<BoolHandler>? = nil
    
    var xposeCnt: Int = 0
    
    init(cardID: String, level: Int, with params: JSONValue) {
        self.cardID = cardID
        self.level = level
        self.params = params
        self.bonusTime = params["bonus_time"]?.doubleValue ?? 0
        self.bonusTimeSkill1 = params["skill1", "bonus_time_skill1"]?.doubleValue ?? 1.0
        self.predictionIntervalInSamples = params["prediction_interval_in_samples"]?.intValue ?? 0
        self.modelKey = params["model_key"]?.stringValue ?? "empty_model"
        self.inputWindowInSamples = params["input_window_in_samples"]?.intValue ?? 0
    }
    
    func load() async -> Bool {
        var sensorTypes: [SensorType] = []
        if let sensorStrings = params["sensor_type"]?.arrayValue?.compactMap({ $0.stringValue }) {
            sensorTypes = sensorStrings.compactMap { SensorType(rawValue: $0) }
        }
        var sensor_location: Int = 0
        if let sensorLocation = params["sensor_location"]?.intValue, DeviceManager.shared.checkSensorLocation(at: sensorLocation >> 1, in: sensorTypes) {
            sensor_location = sensorLocation
            CompetitionManager.shared.sensorRequest |= sensorLocation
        } else {
            if let sensorLocation2 = params["sensor_location2"]?.intValue, DeviceManager.shared.checkSensorLocation(at: sensorLocation2 >> 1, in: sensorTypes) {
                sensor_location = sensorLocation2
                CompetitionManager.shared.sensorRequest |= sensorLocation2
            } else {
                return false
            }
        }
        
        if predictModel == nil {
            if let model = await ModelManager.shared.loadModel(for: modelKey) {
                DataFusionManager.shared.setPredictWindow(maxWindow: inputWindowInSamples)
                predictModel = GenericPredictModel(location: sensor_location, params: params, model: model, handler: BoolHandler())
                // 设置device开启imu收集
                for (pos, dev) in DeviceManager.shared.deviceMap {
                    if var device = dev, (sensor_location & (1 << (pos.rawValue + 1))) != 0 {
                        device.enableIMU = true
                    }
                }
                return true
            } else {
                print("模型 \(modelKey) 加载失败")
                return false
            }
        }
        return true
    }
    
    func register(eventBus: MatchEventBus) {
        eventBus.on(.matchIMUSensorUpdate) { context in
            self.predictModel?.checkForPrediction(with: context.sensorData) { result in
                return self.onPrediction(result: result, context: context)
            }
        }
        eventBus.on(.matchEnd) { context in
            if self.level >= 3 && self.xposeCnt >= 3 {
                context.addOrUpdateBonus(cardID: self.cardID, bonus: self.bonusTimeSkill1)
            }
        }
    }
    
    func onPrediction(result: Bool, context: MatchContext) -> Int {
        if result {
            context.addOrUpdateBonus(cardID: cardID, bonus: bonusTime)
            xposeCnt += 1
            return inputWindowInSamples
        } else {
            return predictionIntervalInSamples
        }
    }
}



