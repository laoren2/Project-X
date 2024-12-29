//
//  PredictionModelML.swift
//  sportsx
//
//  Created by 任杰 on 2024/12/11.
//

import CoreML
import Foundation


// 定义预测结果的通用协议
protocol PredictionOutput {}

// 可以为常用类型扩展该协议
extension Bool: PredictionOutput {}
extension Int: PredictionOutput {}
extension Double: PredictionOutput {}


// 其他类型根据需要扩展


protocol PredictionModel {
    associatedtype Output: PredictionOutput
    
    var id: String {get}
    var modelName: String { get }
    var inputWindowInSamples: Int { get }
    var predictionIntervalInSamples: Int { get set }
    var requiresDecisionBasedInterval: Bool { get }
    var compensationValue: Double { get set }
    func predict(inputData: [CompetitionData], completion: @escaping (Output) -> Void)
    func adjustPredictionInterval(basedOn result: Output)
}

// 类型擦除的PredictionModel包装器
class AnyPredictionModel: Identifiable, Equatable {
    var id: String // 通过 modelName 作为唯一标识符
    var modelName: String
    var inputWindowInSamples: Int
    var predictionIntervalInSamples: Int
    var requiresDecisionBasedInterval: Bool
    var compensationValue: Double
    
    private let _predict: ([CompetitionData], @escaping (Any) -> Void) -> Void
    private let _adjustPredictionInterval: (Any) -> Void
    
    init<M: PredictionModel>(_ model: M) {
        self.id = model.id // 假设 modelName 是唯一的
        self.modelName = model.modelName
        self.inputWindowInSamples = model.inputWindowInSamples
        self.predictionIntervalInSamples = model.predictionIntervalInSamples
        self.requiresDecisionBasedInterval = model.requiresDecisionBasedInterval
        self.compensationValue = model.compensationValue
        
        // 封装预测方法
        self._predict = { inputData, completion in
            model.predict(inputData: inputData) { result in
                completion(result)
            }
        }
        
        // 封装调整预测间隔方法
        self._adjustPredictionInterval = { result in
            if let typedResult = result as? M.Output {
                model.adjustPredictionInterval(basedOn: typedResult)
            } else {
                print("类型转换失败")
            }
        }
    }
    
    // 进行预测
    func predict(inputData: [CompetitionData], completion: @escaping (Any) -> Void) {
        _predict(inputData, completion)
    }
    
    // 根据预测结果调整预测间隔
    func adjustPredictionInterval(basedOn result: Any) {
        _adjustPredictionInterval(result)
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
    
    init(modelInfo: ModelInfo) {
        self.id = modelInfo.id
        self.modelName = modelInfo.modelName
        self.inputWindowInSamples = modelInfo.inputWindowInSamples
        self.predictionIntervalInSamples = modelInfo.predictionIntervalInSamples
        self.requiresDecisionBasedInterval = modelInfo.requiresDecisionBasedInterval
        self.compensationValue = 0
    }
    
    func predict(inputData: [CompetitionData], completion: @escaping (Bool) -> Void) {
        //let mlModel = ModelManager.shared.selectedMLModels[id]
        //let result = mlModel?.prediction(from: )
        let totalAcc = inputData.reduce(0.0) { $0 + sqrt($1.accX * $1.accX + $1.accY * $1.accY + $1.accZ * $1.accZ) }
        let result: Bool = totalAcc > 100 ? true : false
        completion(result)
        print("model \(modelName) predict bool")
    }
    
    func adjustPredictionInterval(basedOn result: Bool) {
        switch result {
        case true:
            predictionIntervalInSamples = 60   // 3秒
        case false:
            predictionIntervalInSamples = 1  // 0.05秒
        }
    }
}

class ModelWithInt: PredictionModel {
    typealias Output = Int
    
    let id: String
    let modelName: String
    let inputWindowInSamples: Int
    var predictionIntervalInSamples: Int
    let requiresDecisionBasedInterval: Bool
    var compensationValue: Double
    
    init(modelInfo: ModelInfo) {
        self.id = modelInfo.id
        self.modelName = modelInfo.modelName
        self.inputWindowInSamples = modelInfo.inputWindowInSamples
        self.predictionIntervalInSamples = modelInfo.predictionIntervalInSamples
        self.requiresDecisionBasedInterval = modelInfo.requiresDecisionBasedInterval
        self.compensationValue = 0
    }
    
    func predict(inputData: [CompetitionData], completion: @escaping (Int) -> Void) {
        //let mlModel = ModelManager.shared.selectedMLModels[id]
        //let result = mlModel?.prediction(from: )
        let result = -1
        completion(result)
        print("model \(modelName) predict int")
    }
    
    func adjustPredictionInterval(basedOn result: Int) {
        
    }
}



