//
//  MagicCardManager.swift
//  sportsx
//
//  Created by 任杰 on 2024/12/26.
//

import Foundation


class MagicCardFactory {
    typealias CardConstructor = (String, Int, JSONValue) -> MagicCardEffect
    private static var registry: [String: CardConstructor] = [:]
    
    static func register(type: String, constructor: @escaping CardConstructor) {
        registry[type] = constructor
    }
    
    static func createEffect(level: Int, from definition: MagicCardDef) -> MagicCardEffect {
        guard let constructor = registry[definition.typeName] else {
            print("No CardEffect registered for type \(definition.typeName)")
            return EmptyCardEffect()
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

class HeartRateBoostEffect: MagicCardEffect {
    let cardID: String
    let level: Int
    let params: JSONValue
    
    let bonusTime: Double
    let bonusTime1: Double
    let bonusTime2: Double
    let bonusTime3: Double
    
    var validTotalTime: Double = 0
    
    init(cardID: String, level: Int, with params: JSONValue) {
        self.cardID = cardID
        self.level = level
        self.bonusTime = params["bonus_time"]?.doubleValue ?? 0
        self.bonusTime1 = params["skill1", "bonus_time1"]?.doubleValue ?? 0
        self.bonusTime2 = params["skill2", "bonus_time2"]?.doubleValue ?? 0
        self.bonusTime3 = params["skill3", "bonus_time3"]?.doubleValue ?? 0
        self.params = params
    }
    
    func load() async -> Bool {
        let sensorLocation = params["sensor_location"]?.intValue ?? 0
        CompetitionManager.shared.sensorRequest |= sensorLocation
        return true
    }
    
    func register(eventBus: MatchEventBus) {
        eventBus.on(.matchCycleUpdate) { context in
            if Int(context.latestHeartRate) >= 90 {
                self.validTotalTime += 3
            }
        }
        eventBus.on(.matchEnd) { context in
            context.addOrUpdateBonus(cardID: self.cardID, bonus: 0.01 * self.bonusTime * self.validTotalTime)
            if self.level >= 3 && Int(context.avgHeartRate) >= 100 {
                context.addOrUpdateBonus(cardID: self.cardID, bonus: self.bonusTime1)
            }
            if self.level >= 6 && Int(context.avgHeartRate) >= 110 {
                context.addOrUpdateBonus(cardID: self.cardID, bonus: self.bonusTime2)
            }
            if self.level == 10 && Int(context.avgHeartRate) >= 120 {
                context.addOrUpdateBonus(cardID: self.cardID, bonus: self.bonusTime3)
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
    let sensorLocation: Int
    
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
        self.sensorLocation = params["sensor_location"]?.intValue ?? 0
    }
    
    func load() async -> Bool {
        if predictModel == nil {
            if let model = await ModelManager.shared.loadModel(for: modelKey) {
                CompetitionManager.shared.sensorRequest |= sensorLocation
                DataFusionManager.shared.setPredictWindow(maxWindow: inputWindowInSamples)
                predictModel = GenericPredictModel(params: params, model: model, handler: BoolHandler())
                // 设置device开启imu收集
                for (pos, dev) in DeviceManager.shared.deviceMap {
                    if var device = dev, (sensorLocation & (1 << (pos.rawValue + 1))) != 0 {
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

/*struct TeamEffect: MagicCardEffect {
    let bonusTime: Double
    
    func register(eventBus: MatchEventBus) {
        eventBus.on(.matchEnd) { context in
            
        }
    }
}*/

class PedalRPMEffect: MagicCardEffect {
    let cardID: String
    let level: Int
    let params: JSONValue
    
    let threshold: Double
    let bonusMultiplier: Double
    
    let thresholdSkill1: Double
    let bonusMultiplierSkill1: Double
    let predictionIntervalInSamples: Int
    
    private let modelKey: String
    private var predictModel: GenericPredictModel<IntHandler>? = nil
    
    var pedalCnt: Int = 0
    
    init(cardID: String, level: Int, with params: JSONValue) {
        self.cardID = cardID
        self.level = level
        self.params = params
        self.threshold = params["threshold"]?.doubleValue ?? 0
        self.bonusMultiplier = params["bonus_multiplier"]?.doubleValue ?? 1.0
        self.thresholdSkill1 = params["skill1", "threshold_skill1"]?.doubleValue ?? 0
        self.bonusMultiplierSkill1 = params["skill1", "bonus_multiplier_skill1"]?.doubleValue ?? 1.0
        self.predictionIntervalInSamples = params["predictionIntervalInSamples"]?.intValue ?? 0
        self.modelKey = params["model_key"]?.stringValue ?? "empty_model"
    }
    
    func load() async -> Bool {
        if predictModel == nil {
            if let model = await ModelManager.shared.loadModel(for: modelKey) {
                let inputWindowInSamples = params["input_window_in_samples"]?.intValue ?? 0
                let sensorLocation = params["sensor_location"]?.intValue ?? 0
                CompetitionManager.shared.sensorRequest |= sensorLocation
                DataFusionManager.shared.setPredictWindow(maxWindow: inputWindowInSamples)
                predictModel = GenericPredictModel(params: params, model: model, handler: IntHandler())
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
                self.onPrediction(result: result)
                // 根据结果调整下次预测的时机
                return self.nextPredictStep()
            }
        }
        eventBus.on(.matchEnd) { context in
            let recordingMin = DataFusionManager.shared.elapsedTime / 60
            let pedalAvg = Double(self.pedalCnt) / recordingMin
            if pedalAvg >= self.threshold {
                let bonus = self.bonusMultiplier * DataFusionManager.shared.elapsedTime
                context.addOrUpdateBonus(cardID: self.cardID, bonus: bonus)
            }
            if self.level >= 3 && pedalAvg >= self.thresholdSkill1 {
                let bonus = self.bonusMultiplierSkill1 * DataFusionManager.shared.elapsedTime
                context.addOrUpdateBonus(cardID: self.cardID, bonus: bonus)
            }
        }
    }
    
    func onPrediction(result: Int) {
        pedalCnt += result
    }
    
    func nextPredictStep() -> Int {
        return predictionIntervalInSamples
    }
}



