//
//  PredictionModelML.swift
//  sportsx
//
//  Created by 任杰 on 2024/12/11.
//

import CoreML
import Foundation
import os


// 定义预测结果的通用协议
protocol PredictionOutput {}

// 可以为常用类型扩展该协议
extension Bool: PredictionOutput {}
extension Int: PredictionOutput {}
extension Double: PredictionOutput {}


// 其他类型根据需要扩展


enum InputData {
    case phoneDataValue([PhoneData?])
    case sensorDataValue([SensorTrainingData?])
}

protocol PredictionModel {
    associatedtype Output: PredictionOutput
    
    var id: String {get}
    var modelName: String { get }
    var inputWindowInSamples: Int { get }
    var predictionIntervalInSamples: Int { get set }
    var requiresDecisionBasedInterval: Bool { get }
    var compensationValue: Double { get set } // 取决于MagicCard
    var sensorLocation: Int { get }
    var isPhoneData: Bool {get}
    
    func predict(inputData: [Float], completion: @escaping (Output) -> Void)
    func adjustPredictionInterval(basedOn result: Output) -> Int
}

// 类型擦除的PredictionModel包装器
class AnyPredictionModel: Identifiable, Equatable {
    var id: String // 通过 modelName 作为唯一标识符
    var modelName: String
    var inputWindowInSamples: Int
    var predictionIntervalInSamples: Int
    var requiresDecisionBasedInterval: Bool
    var compensationValue: Double
    var sensorLocation: Int
    var isPhoneData: Bool
    
    private let _predict: ([Float], @escaping (Any) -> Void) -> Void
    private let _adjustPredictionInterval: (Any) -> Int
    
    init<M: PredictionModel>(_ model: M) {
        self.id = model.id // 假设 modelName 是唯一的
        self.modelName = model.modelName
        self.inputWindowInSamples = model.inputWindowInSamples
        self.predictionIntervalInSamples = model.predictionIntervalInSamples
        self.requiresDecisionBasedInterval = model.requiresDecisionBasedInterval
        self.compensationValue = model.compensationValue
        self.sensorLocation = model.sensorLocation
        self.isPhoneData = model.isPhoneData
        
        // 封装预测方法
        self._predict = { inputData, completion in
            model.predict(inputData: inputData) { result in
                completion(result)
            }
        }
        
        // 封装调整预测间隔方法
        self._adjustPredictionInterval = { result in
            if let typedResult = result as? M.Output {
                return model.adjustPredictionInterval(basedOn: typedResult)
            } else {
                print("类型转换失败")
                return -1
            }
        }
    }
    
    // 进行预测
    func predict(inputData: [Float], completion: @escaping (Any) -> Void) {
        _predict(inputData, completion)
    }
    
    // 根据预测结果调整预测间隔
    func adjustPredictionInterval(basedOn result: Any) -> Int {
        return _adjustPredictionInterval(result)
    }
    
    // Equatable 协议实现
    static func == (lhs: AnyPredictionModel, rhs: AnyPredictionModel) -> Bool {
        return lhs.modelName == rhs.modelName
    }
}


class ModelWithBool: PredictionModel, Codable {
    typealias Output = Bool
    
    let id: String
    let modelName: String
    let inputWindowInSamples: Int
    var predictionIntervalInSamples: Int
    let requiresDecisionBasedInterval: Bool
    var compensationValue: Double
    let sensorLocation: Int
    var isPhoneData: Bool
    
    
    init(modelInfo: ModelInfo) {
        self.id = modelInfo.id
        self.modelName = modelInfo.modelName
        self.inputWindowInSamples = modelInfo.inputWindowInSamples
        self.predictionIntervalInSamples = modelInfo.predictionIntervalInSamples
        self.requiresDecisionBasedInterval = modelInfo.requiresDecisionBasedInterval
        self.compensationValue = 0
        self.sensorLocation = modelInfo.sensorLocation
        self.isPhoneData = modelInfo.isPhoneData
    }
    
    // todo: 使用原始数据，默认不使用MLModel预测
    func predict(inputData: [Float], completion: @escaping (Bool) -> Void) {
        //switch inputData {
        //case .phoneDataValue(let value):
            // todo: fake mlmodel predict
            //print("fake mlmodel predict")
        //case .sensorDataValue(let value):
        //}
        Logger.competition.notice_public("inputData count: \(inputData.count)")
        if let mlModel = ModelManager.shared.selectedMLModels[id] {
            let inputProvider = ModelInput(inputData: inputData)
            do {
                let result = try mlModel.prediction(from: inputProvider)
                
                // 获取预测结果
                if let result = result.featureValue(for: "Identity")?.multiArrayValue {
                    // 将输出转换为二分类结果
                    let floatValue = result[0].floatValue
                    let boolValue = floatValue >= 0.5 // 如果大于等于0.5则为1，否则为0
                    Logger.competition.notice_public("predict result: \(boolValue)")
                    completion(boolValue)
                } else {
                    Logger.competition.notice_public("predict result not found")
                }
            } catch {
                Logger.competition.notice_public("predict error: \(error)")
            }
        } else {
            Logger.competition.notice_public("compiled model not found")
        }
    }
    
    func adjustPredictionInterval(basedOn result: Bool) -> Int {
        return result ? inputWindowInSamples : predictionIntervalInSamples
    }
}

// todo
// 待完善
class ModelWithInt: PredictionModel {
    typealias Output = Int
    
    let id: String
    let modelName: String
    let inputWindowInSamples: Int
    var predictionIntervalInSamples: Int
    let requiresDecisionBasedInterval: Bool
    var compensationValue: Double
    let sensorLocation: Int
    var isPhoneData: Bool
    
    init(modelInfo: ModelInfo) {
        self.id = modelInfo.id
        self.modelName = modelInfo.modelName
        self.inputWindowInSamples = modelInfo.inputWindowInSamples
        self.predictionIntervalInSamples = modelInfo.predictionIntervalInSamples
        self.requiresDecisionBasedInterval = modelInfo.requiresDecisionBasedInterval
        self.compensationValue = 0
        self.sensorLocation = modelInfo.sensorLocation
        self.isPhoneData = modelInfo.isPhoneData
    }
    
    // todo: 使用原始数据，默认不使用MLModel预测
    func predict(inputData: [Float], completion: @escaping (Int) -> Void) {
        //switch inputData {
        //case .phoneDataValue(let value):
            // todo: fake mlmodel predict
            //print("fake mlmodel predict")
        //case .sensorDataValue(let value):
            //let mlModel = ModelManager.shared.selectedMLModels[id]
            //let result = mlModel?.prediction(from: )
        //}
        let result = -1
        completion(result)
        print("model \(modelName) predict int")
    }
    
    func adjustPredictionInterval(basedOn result: Int) -> Int {
        return -1
    }
}



