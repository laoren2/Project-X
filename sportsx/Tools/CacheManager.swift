//
//  CacheManager.swift
//  sportsx
//
//  Created by 任杰 on 2025/6/7.
//

import Foundation


class CacheManager {
    static let shared = CacheManager()

    private init() {}

    /// 获取当前缓存总大小（包括 URLCache 和 tmp 文件）
    func getCacheSize(completion: @escaping (Int64) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let cacheSize = self.getURLCacheSize()
            let tmpSize = self.getTmpDirectorySize()
            let total = cacheSize + tmpSize
            completion(total)
        }
    }

    /// 清除缓存数据（包括 URLCache 和 tmp 文件）
    func clearAllCache(completion: ((Bool) -> Void)? = nil) {
        URLCache.shared.removeAllCachedResponses()
        clearTmpDirectory()
        // 后台间隔0.2s循环检查是否删除完，删完后执行completion
        DispatchQueue.global(qos: .background).async {
            let checkInterval: TimeInterval = 0.2
            let timeout: TimeInterval = 3.0
            var elapsed: TimeInterval = 0.0
            Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { timer in
                // 检查是否已清理完成
                let remainingFiles = (try? FileManager.default.contentsOfDirectory(at: FileManager.default.temporaryDirectory, includingPropertiesForKeys: nil)) ?? []
                if remainingFiles.isEmpty {
                    timer.invalidate()
                    completion?(true)
                } else if elapsed > timeout {
                    timer.invalidate()
                    completion?(false)
                }
                elapsed += checkInterval
            }
            RunLoop.current.run(until: Date().addingTimeInterval(timeout)) // 让定时器正常运行
        }
    }

    // MARK: - URLCache 管理

    private func getURLCacheSize() -> Int64 {
        // URLCache 并没有提供获取大小的 API，只能估算
        return Int64(URLCache.shared.currentDiskUsage + URLCache.shared.currentMemoryUsage)
    }

    // MARK: - tmp 文件管理

    private func getTmpDirectorySize() -> Int64 {
        let tmpURL = FileManager.default.temporaryDirectory
        return directorySize(at: tmpURL)
    }

    private func clearTmpDirectory() {
        let tmpURL = FileManager.default.temporaryDirectory
        removeContents(of: tmpURL)
    }

    // MARK: - 自定义缓存目录支持

    func directorySize(at url: URL) -> Int64 {
        var size: Int64 = 0
        let fileManager = FileManager.default
        if let files = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey], options: .skipsHiddenFiles) {
            for file in files {
                if let fileSize = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    size += Int64(fileSize)
                }
            }
        }
        return size
    }

    func removeContents(of directoryURL: URL) {
        let fileManager = FileManager.default
        
        if let files = try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }
    }
}
