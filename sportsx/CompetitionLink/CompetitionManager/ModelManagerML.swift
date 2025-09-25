//
//  ModelManagerML.swift
//  sportsx
//
//  Created by 任杰 on 2024/12/5.
//

import Foundation
import Combine
import CryptoKit
import CoreML
import os
import ZIPFoundation



final class ModelManager {
    static let shared = ModelManager()
    
    private init() {}
    
    private let fileManager = FileManager.default
    private let modelsDirectory: URL = {
        let supportDir = try! FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = supportDir.appendingPathComponent("models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    
    private var indexFile: URL {
        modelsDirectory.appendingPathComponent("index.json")
    }
    
    private var modelIndex: [String: String] = [:] // model_key : version
    
    // app 启动时调用
    func loadIndex() {
        if let data = try? Data(contentsOf: indexFile),
           let index = try? JSONDecoder().decode([String: String].self, from: data) {
            modelIndex = index
            print("load model index success")
        } else {
            print("model index not found")
        }
    }
    
    private func saveIndex() {
        if let data = try? JSONEncoder().encode(modelIndex) {
            try? data.write(to: indexFile)
        }
    }
    
    // 检查并更新所有需要的模型
    func syncModels() {
        Task {
            for key in modelIndex.keys {
                await checkAndUpdateModel(key: key)
            }
        }
    }
    
    // 检查并更新单个模型
    func checkAndUpdateModel(key: String) async {
        let result = await NetworkService.downloadResourceAsync(path: "/resources/model/\(key)/config.json", decodingType: ModelConfig.self)
        
        switch result {
        case .success(let data):
            let localVersion = modelIndex[key]
            if localVersion != data.version {
                await downloadModel(from: data.url, modelKey: key, version: data.version)
            }
        default:
            break
        }
    }
    
    // 下载模型文件
    func downloadModel(from urlString: String, modelKey: String, version: String) async {
        guard let url = URL(string: urlString) else { return }
        let result = await NetworkService.downloadFileAsync(from: url)
        switch result {
        case .success(let tmpFileURL):
            let destFileName = "\(modelKey)_\(version).mlpackage"
            let destFileURL = modelsDirectory.appendingPathComponent(destFileName)
            
            // 删除旧版本文件
            if let oldVersion = modelIndex[modelKey] {
                let oldFile = modelsDirectory.appendingPathComponent("\(modelKey)_\(oldVersion).mlpackage")
                try? fileManager.removeItem(at: oldFile)
            }
            
            do {
                // 先解压到一个临时目录
                let tempUnzipDir = modelsDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
                try fileManager.createDirectory(at: tempUnzipDir, withIntermediateDirectories: true)
                try fileManager.unzipItem(at: tmpFileURL, to: tempUnzipDir)
                // 找到并移动解压出来的唯一的 .mlpackage
                let contents = try fileManager.contentsOfDirectory(at: tempUnzipDir, includingPropertiesForKeys: nil)
                if let unpacked = contents.first(where: { $0.pathExtension == "mlpackage" }) {
                    try? fileManager.removeItem(at: destFileURL) // 避免残留
                    try fileManager.moveItem(at: unpacked, to: destFileURL)
                    print("解压并重命名完成: \(destFileURL)")
                } else {
                    print("未找到解压后的 mlpackage 文件")
                }
                // 清理临时目录
                try? fileManager.removeItem(at: tempUnzipDir)
            } catch {
                print("解压文件失败: \(error)")
                return
            }
            
            // 检查解压结果
            if !fileManager.fileExists(atPath: destFileURL.path) {
                print("找不到解压文件")
                return
            }
            
            // 更新索引
            modelIndex[modelKey] = version
            saveIndex()
            print("成功更新模型：\(modelKey) \(modelIndex[modelKey] ?? "none") → \(version)")
        default:
            break
        }
    }
    
    // 获取本地某个模型的URL（如果存在）
    private func getLocalModelURL(for modelKey: String) -> URL? {
        guard let version = modelIndex[modelKey] else { return nil }
        let fileName = "\(modelKey)_\(version).mlpackage"
        let modelURL = modelsDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: modelURL.path) ? modelURL : nil
    }
    
    // 加载某个模型（必要时会触发更新下载）
    func loadModel(for modelKey: String) async -> MLModel? {
        // 1. 获取本地模型URL
        var modelURL = getLocalModelURL(for: modelKey)
        
        // 2. 如果本地不存在 → 尝试更新并获取
        if modelURL == nil {
            await checkAndUpdateModel(key: modelKey)
            modelURL = getLocalModelURL(for: modelKey)
        }
        
        guard let finalURL = modelURL else {
            print("模型文件不存在: \(modelKey)")
            return nil
        }
        
        // 3. 编译并加载模型
        do {
            let compiledURL = try await MLModel.compileModel(at: finalURL)
            let model = try MLModel(contentsOf: compiledURL)
            return model
        } catch {
            print("模型编译失败 (\(modelKey)): \(error)")
            return nil
        }
    }
}

// MARK: - 模型配置结构
struct ModelConfig: Codable {
    //let model_key: String
    let version: String // v2, v3, ...
    let url: String
}

struct ModelInfo: Codable, Identifiable {
    let id: String // 对应唯一的 model_id
    let version: String // 当前版本号
    let downloadURL: URL
    let checksum: String // 用于验证模型合法性的 SHA256 哈希值
    let modelName: String
    let inputWindowInSamples: Int // 模型的输入长度，单位是一次的采集样本
    var predictionIntervalInSamples: Int // 模型的初始预测间隔，单位是一次的采集样本
    var requiresDecisionBasedInterval: Bool // 模型是否需要动态调整预测间隔
    let sensorLocation: Int // 模型需要的传感器配置，当前允许5+1个传感器
    var isPhoneData: Bool // 为true时代表输入仅为原始phone数据，同时sensorLocation必须为0b000001，为false时phone位置使用其sensor数据
    let outputType: String // 模型的输出类型，当前支持Bool和Int
    
    enum CodingKeys: String, CodingKey {
        case id = "model_id"
        case version
        case downloadURL = "download_url"
        case checksum
        case modelName = "model_name"
        case inputWindowInSamples = "input_window_in_samples"
        case predictionIntervalInSamples = "prediction_interval_in_samples"
        case requiresDecisionBasedInterval = "requires_decision_based_interval"
        case sensorLocation = "sensor_location"
        case isPhoneData = "is_phone_data"
        case outputType = "output_type"
    }
}


struct UserModelsResponse: Codable {
    let models: [ModelInfo]
}


