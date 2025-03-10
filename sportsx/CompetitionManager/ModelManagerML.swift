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

class ModelManager: ObservableObject {
    static let shared = ModelManager()
    
    var availableModelInfos: [String: AnyPredictionModel] = [:]
    var selectedModelInfos: [AnyPredictionModel] = []
    var selectedMLModels: [String: MLModel] = [:]
    
    var maxInputWindow: Int = 0
    
    // 仅用于调试
    @Published var isUpdating: Bool = false
    @Published var updateProgress: Double = 0.0
    @Published var errorMessage: String?
    
    private var modelsDirectory: URL
    private let metadataFile: URL
    private let session: URLSession
    private let metadataQueue = DispatchQueue(label: "com.sportsx.modelmanager.metadata", attributes: .concurrent)
        
    private var localModelMetadata: [String: ModelMetadata] = [:]
        
    struct ModelMetadata: Codable {
        let version: String
        let checksum: String
    }
    
    
    private init() {
        // 获取 Application Support 目录
        let fileManager = FileManager.default
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            self.modelsDirectory = appSupportURL.appendingPathComponent("Models")
        } else {
            fatalError("Unable to access Application Support directory.")
        }
                
        // 创建 Models 目录
        if !fileManager.fileExists(atPath: modelsDirectory.path) {
            do {
                try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                fatalError("Failed to create Models directory: \(error)")
            }
        }
        
        // 设置 modelsDirectory 不被备份到 iCloud
        do {
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try modelsDirectory.setResourceValues(resourceValues)
            print("成功设置 \(modelsDirectory.path) 不被备份到 iCloud")
        } catch {
            print("无法设置 \(modelsDirectory.path) 不被备份到 iCloud: \(error)")
        }
                
        // 元数据文件路径
        self.metadataFile = modelsDirectory.appendingPathComponent("metadata.json")
                
        self.session = URLSession(configuration: .default)
        
        // 加载本地元数据
        self.loadLocalMetadata()
    }
    
    // 加载本地元数据
    private func loadLocalMetadata() {
        metadataQueue.sync {
            do {
                let data = try Data(contentsOf: metadataFile)
                let decoder = JSONDecoder()
                self.localModelMetadata = try decoder.decode([String: ModelMetadata].self, from: data)
            } catch {
                // 如果没有元数据文件或解析失败，初始化为空
                self.localModelMetadata = [:]
            }
        }
    }
        
    // 保存本地元数据
    private func saveLocalMetadata() {
        metadataQueue.async(flags: .barrier) {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(self.localModelMetadata)
                try data.write(to: self.metadataFile)
            } catch {
                print("Failed to save metadata: \(error)")
            }
        }
    }
    
    // 获取服务器上的模型列表
    func fetchUserModels() async throws -> [ModelInfo] {
        guard let url = URL(string: "https://yourserver.com/api/user/models") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        // 添加必要的认证头部，例如Token
        request.addValue("Bearer YOUR_AUTH_TOKEN", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        // 检查响应状态码
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        let userModelsResponse = try decoder.decode(UserModelsResponse.self, from: data)
        return userModelsResponse.models
    }
        
    // 下载并验证模型文件
    private func downloadAndValidate(model: ModelInfo) async throws {
        let (tempURL, response) = try await session.download(from: model.downloadURL)
        
        // 检查响应状态码
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }
        
        // 计算下载文件的 SHA256 哈希值
        let downloadedData = try Data(contentsOf: tempURL)
        let hash = SHA256.hash(data: downloadedData)
        let downloadedChecksum = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        guard downloadedChecksum.lowercased() == model.checksum.lowercased() else {
            throw NSError(domain: "Checksum mismatch", code: -1, userInfo: nil)
        }
        
        // 保存模型文件到 Models 目录
        let destinationURL = modelsDirectory.appendingPathComponent("\(model.id).mlpackage")
        try FileManager.default.removeItem(at: destinationURL) // 如果存在则删除
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        
        //return destinationURL
    }
        
    func updateModels() async {
        /*
        // 更新状态为正在更新
        await MainActor.run {
            self.isUpdating = true
            self.updateProgress = 0.0
            self.errorMessage = nil
            self.availableModelInfos = []
        }
        
        do {
            let serverModels = try await fetchUserModels()
            let totalModels = serverModels.count
            var errors: [Error] = []
            
            let models: [AnyPredictionModel] = serverModels.map { modelInfo in
                switch modelInfo.outputType.lowercased() {
                case "bool":
                    return AnyPredictionModel(ModelWithBool(modelInfo: modelInfo))
                case "int":
                    return AnyPredictionModel(ModelWithInt(modelInfo: modelInfo))
                default:
                    return AnyPredictionModel(ModelWithBool(modelInfo: modelInfo)) // 默认使用输出type为bool的模型
                }
            }
                        
            await MainActor.run {
                self.availableModelInfos = models
            }
            
            // 设置最大并发下载数量
            let maxConcurrentDownloads = 4
            
            // 使用 TaskGroup 进行并发下载，并限制并发数量
            try await withThrowingTaskGroup(of: Error?.self) { group in
                var iterator = serverModels.makeIterator()
                
                // 初始添加最多 maxConcurrentDownloads 个任务
                for _ in 0..<maxConcurrentDownloads {
                    if let model = iterator.next() {
                        group.addTask {
                            do {
                                try await self.processModel(model: model)
                                await MainActor.run {
                                    self.updateProgress += 1.0 / Double(totalModels)
                                }
                                return nil
                            } catch {
                                await MainActor.run {
                                    self.updateProgress += 1.0 / Double(totalModels)
                                }
                                return error
                            }
                        }
                    }
                }
                
                // 当有任务完成时，添加新的任务
                while let model = iterator.next() {
                    // 等待任意一个任务完成
                    if let _ = try await group.next() {
                        // 如果任务返回了错误，已在返回值中处理
                    }
                    
                    // 添加新的任务
                    group.addTask {
                        do {
                            try await self.processModel(model: model)
                            await MainActor.run {
                                self.updateProgress += 1.0 / Double(totalModels)
                            }
                            return nil
                        } catch {
                            await MainActor.run {
                                self.updateProgress += 1.0 / Double(totalModels)
                            }
                            return error
                        }
                    }
                }
                
                // 等待所有任务完成，并收集错误
                for try await error in group {
                    if let error = error {
                        errors.append(error)
                    }
                }
            }
            
            // 保存本地元数据
            self.saveLocalMetadata()
            
            let finalErrors = errors
            
            // 更新状态为完成，并处理可能的错误
            await MainActor.run {
                self.isUpdating = false
                if !finalErrors.isEmpty {
                    self.errorMessage = "部分模型更新失败: \(finalErrors.first?.localizedDescription ?? "未知错误")"
                }
            }
        } catch {
            // 处理总体错误
            await MainActor.run {
                self.isUpdating = false
                self.errorMessage = "模型更新失败: \(error.localizedDescription)"
            }
        }*/
        
        // 本地调试使用
        let model1 = ModelInfo(
            id: "model_001",
            version: "1.0",
            downloadURL: URL(string: "https://example.com/models/model1.zip")!,
            checksum: "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
            modelName: "ImageClassifier",
            inputWindowInSamples: 60,
            predictionIntervalInSamples: 1,
            requiresDecisionBasedInterval: true,
            sensorLocation: 0b000001,
            isPhoneData: true,
            outputType: "bool"
        )

        let model2 = ModelInfo(
            id: "model_002",
            version: "2.1",
            downloadURL: URL(string: "https://example.com/models/model2.zip")!,
            checksum: "123456abcdef123456abcdef123456abcdef123456abcdef123456abcdef1234",
            modelName: "SpeechRecognizer",
            inputWindowInSamples: 60,
            predictionIntervalInSamples: 1,
            requiresDecisionBasedInterval: true,
            sensorLocation: 0b000010,
            isPhoneData: false,
            outputType: "bool"
        )

        let model3 = ModelInfo(
            id: "model_003",
            version: "3.0",
            downloadURL: URL(string: "https://example.com/models/model3.zip")!,
            checksum: "fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321",
            modelName: "TextGenerator",
            inputWindowInSamples: 200,
            predictionIntervalInSamples: 200,
            requiresDecisionBasedInterval: false,
            sensorLocation: 0b000101,
            isPhoneData: false,
            outputType: "int"
        )
        
        // 调试用模型，对应上面model2配置
        if let resourceBundle = Bundle(path: Bundle.main.bundlePath + "/resources.bundle"),
           let modelURL = resourceBundle.url(forResource: "xpose_tcn_model", withExtension: "mlpackage") {
            copyModelToApplicationSupportDirectory(from: modelURL)
        } else {
            Logger.competition.notice_public("xpose_tcn_model not found")
        }

        // 将实例添加到数组中
        let serverModels = [model1, model2, model3]
        
        let models: [AnyPredictionModel] = serverModels.map { modelInfo in
            switch modelInfo.outputType.lowercased() {
            case "bool":
                return AnyPredictionModel(ModelWithBool(modelInfo: modelInfo))
            case "int":
                return AnyPredictionModel(ModelWithInt(modelInfo: modelInfo))
            default:
                return AnyPredictionModel(ModelWithBool(modelInfo: modelInfo)) // 默认使用输出type为bool的模型
            }
        }
                    
        await MainActor.run {
            for model in models {
                self.availableModelInfos[model.id] = model
            }
        }
    }

    // 处理单个模型的下载和验证
    private func processModel(model: ModelInfo) async throws {
        if let localMetadata = self.localModelMetadata[model.id] {
            if localMetadata.version != model.version {
                try await self.downloadAndValidate(model: model)
                self.localModelMetadata[model.id] = ModelMetadata(version: model.version, checksum: model.checksum)
            }
        } else {
            try await self.downloadAndValidate(model: model)
            self.localModelMetadata[model.id] = ModelMetadata(version: model.version, checksum: model.checksum)
        }
    }

    // 测试使用
    func copyModelToApplicationSupportDirectory(from myURL: URL) {
        // 获取应用的 applicationSupportDirectory
        let fileManager = FileManager.default
        do {
            // 获取目标文件的 URL
            let destinationURL = modelsDirectory.appendingPathComponent("model_002.mlpackage")
            
            // 检查目标文件是否已经存在，避免覆盖
            if fileManager.fileExists(atPath: destinationURL.path) {
                Logger.competition.notice_public("model has existed, skipping copy...")
            } else {
                // 将文件从自定义 bundle 复制到 Models 文件夹
                try fileManager.copyItem(at: myURL, to: destinationURL)
                Logger.competition.notice_public("model has copied to: \(destinationURL.path)")
            }
        } catch {
            Logger.competition.notice_public("model copy error: \(error.localizedDescription)")
        }
    }
    
    // 加载 CoreML 模型
    func loadModel(modelID: String) -> MLModel? {
        guard let modelURL = getLocalModelURL(modelID: modelID) else {
            Logger.competition.notice_public("original model not found")
            return nil
        }
        
        do {
            let compiledURL = try MLModel.compileModel(at: modelURL)
            do {
                let model = try MLModel(contentsOf: compiledURL)
                return model
            } catch {
                Logger.competition.notice_public("model load error: \(error)")
                return nil
            }
        } catch {
            print("model compile error: \(error)")
            return nil
        }
    }
        
    // 获取本地模型URL
    func getLocalModelURL(modelID: String) -> URL? {
        let modelURL = modelsDirectory.appendingPathComponent("\(modelID).mlpackage")
        return FileManager.default.fileExists(atPath: modelURL.path) ? modelURL : nil
    }
    
    // 加载用户已选择的模型
    func selectModels(_ cards: [MagicCard]) {
        selectedModelInfos = []
        // 确保最多选择3个模型
        guard cards.count <= 3 else {
            print("最多选择3个卡片")
            return
        }
        
        // 将magiccard对应的Model加入SelectedModel
        // todo: 去重
        for card in cards {
            if let model = availableModelInfos[card.modelID] {
                model.compensationValue = card.compensationValue
                selectedModelInfos.append(model)
                maxInputWindow = max(maxInputWindow, model.inputWindowInSamples)
            }
            else {
                print("model of \(card.name) card is not found!")
            }
        }
    }
    
    func loadSelectedModels() async {
        // 重置 selectedMLModels
        await MainActor.run {
            self.selectedMLModels = [:]
        }
        
        for model in selectedModelInfos {
            let mlModel = loadModel(modelID: model.id)
            // 添加到 selectedMLModels
            await MainActor.run {
                self.selectedMLModels[model.id] = mlModel
            }
        }
    }
    
    func resetAll() {
        maxInputWindow = 0
        selectedModelInfos.removeAll()
        selectedMLModels.removeAll()
    }
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


