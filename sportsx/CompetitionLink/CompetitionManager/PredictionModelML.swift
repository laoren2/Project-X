//
//  PredictionModelML.swift
//  sportsx
//
//  Created by 任杰 on 2024/12/11.
//

import CoreML
import Foundation
import os


protocol PredictionOutputHandler {
    associatedtype Output
    func parse(from result: MLMultiArray) -> Output?
}

class GenericPredictModel<Handler: PredictionOutputHandler> {
    let inputWindowInSamples: Int
    let predictionIntervalInSamples: Int
    //let requiresDecisionBasedInterval: Bool
    let sensorLocation: Int
    let isPhoneData: Bool
    var remainingSamples: Int
    
    let mlModel: MLModel
    let handler: Handler
    
    init(params: JSONValue, model: MLModel, handler: Handler) {
        self.inputWindowInSamples = params["input_window_in_samples"]?.intValue ?? 0
        self.predictionIntervalInSamples = params["prediction_interval_in_samples"]?.intValue ?? 0
        //self.requiresDecisionBasedInterval = params["requires_decision_based_interval"]?.boolValue ?? false
        self.sensorLocation = params["sensor_location"]?.intValue ?? 0
        self.isPhoneData = params["is_phone_data"]?.boolValue ?? false
        self.remainingSamples = self.predictionIntervalInSamples
        self.mlModel = model
        self.handler = handler
    }
    
    func checkForPrediction(with data: DataSnapshot, completion: @escaping (Handler.Output) -> Int) {
        for i in 0..<data.predictTime {
            remainingSamples -= 1
            if remainingSamples <= 0 {
                // 到达预测时机
                let lastToEnd = data.predictTime - i - 1
                let total = data.phoneSlice.count - lastToEnd
                // 数据不足时跳过此次预测
                if total >= inputWindowInSamples {
                    performPrediction(with: data, atLast: lastToEnd, completion: completion)
                }
            }
        }
    }
    
    private func performPrediction(with data: DataSnapshot, atLast lastToEnd: Int, completion: @escaping (Handler.Output) -> Int) {
        // 获取模型需要的输入数据(最近model.inputWindowInSamples条数据)
        let inputData = isPhoneData
        ? DataFusionManager.getLastPhoneSamples(count: inputWindowInSamples, data: data.phoneSlice, before: lastToEnd)
        : DataFusionManager.getLastSensorSamples(sensorLocation: sensorLocation, count: inputWindowInSamples, data: data.sensorSlice, before: lastToEnd)
        
        //Logger.competition.notice_public("inputData count: \(inputData.count)")
        if let inputProvider = ModelInput(model: mlModel, inputData: inputData) {
            do {
                let result = try mlModel.prediction(from: inputProvider)
                // 获取预测结果
                if let result = result.featureValue(for: "Identity")?.multiArrayValue, let output = handler.parse(from: result) {
                    //Logger.competition.notice_public("predict result: \(output)")
                    remainingSamples = completion(output)
                } else {
                    Logger.competition.notice_public("predict result not found")
                }
            } catch {
                Logger.competition.notice_public("predict error: \(error)")
            }
        } else {
            Logger.competition.notice_public("model input error")
        }
    }
    
    //func adjustPredictionInterval(basedOn result: Bool) -> Int {
    //    return result ? inputWindowInSamples : predictionIntervalInSamples
    //}
}

struct BoolHandler: PredictionOutputHandler {
    func parse(from result: MLMultiArray) -> Bool? {
        let floatValue = result[0].floatValue
        return floatValue >= 0.9
    }
}

struct IntHandler: PredictionOutputHandler {
    func parse(from result: MLMultiArray) -> Int? {
        return result[0].intValue
    }
}

struct FloatHandler: PredictionOutputHandler {
    func parse(from result: MLMultiArray) -> Float? {
        return result[0].floatValue
    }
}

class ModelInput: NSObject, MLFeatureProvider {
    let input: MLMultiArray
    let featureName: String
    
    var featureNames: Set<String> { [featureName] }
    
    init?(model: MLModel, inputData: [Float]) {
        // 拿第一个输入名字
        guard let firstInput = model.modelDescription.inputDescriptionsByName.keys.first else { return nil }
        self.featureName = firstInput
        
        // 创建 MLMultiArray
        let shape = [1, NSNumber(value: inputData.count), 1]
        self.input = try! MLMultiArray(shape: shape, dataType: .float32)
        
        // 填充
        for (i, v) in inputData.enumerated() {
            self.input[i] = NSNumber(value: v)
        }
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        return featureName == self.featureName ? MLFeatureValue(multiArray: input) : nil
    }
}
