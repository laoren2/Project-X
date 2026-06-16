//
//  PendingUploadManager.swift
//  sportsx
//
//  运动结束数据本地 outbox：上传失败时落盘保存，网络恢复后由用户手动重传。
//  存储位置：<Application Support>/PendingUploads/<userID>/<uploadID>.json
//  - Application Support 不会被系统自动回收（区别于 tmp / Caches）
//  - 按 userID 分目录，天然隔离多用户，登出再登录数据仍在
//
//  Created by Claude on 2026/6/15.
//

import Foundation
import OSLog


final class PendingUploadManager {
    static let shared = PendingUploadManager()
    private init() {}

    private let fileManager = FileManager.default

    // MARK: - 路径

    // <Application Support>/PendingUploads/<userID>/
    private func directory(for userID: String) -> URL? {
        guard !userID.isEmpty,
              let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return base
            .appendingPathComponent("PendingUploads", isDirectory: true)
            .appendingPathComponent(userID, isDirectory: true)
    }

    private func fileURL(id: String, userID: String) -> URL? {
        directory(for: userID)?.appendingPathComponent("\(id).json")
    }

    // MARK: - 写入 / 删除

    /// 写前落盘：在发起 finish 请求前保存，这样即使请求中途 App 被杀，数据仍在磁盘
    @discardableResult
    func save(_ upload: PendingWorkoutUpload) -> Bool {
        guard let dir = directory(for: upload.userID),
              let url = fileURL(id: upload.id, userID: upload.userID) else {
            return false
        }
        do {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(upload)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            Logger.competition.error_public("save pending upload failed: \(error.localizedDescription)")
            return false
        }
    }

    /// 上传成功或用户主动删除时移除
    func remove(id: String, userID: String) {
        guard let url = fileURL(id: id, userID: userID) else { return }
        try? fileManager.removeItem(at: url)
    }

    // MARK: - 读取

    /// 读取当前用户某类别 + 运动的待上传列表（按时间倒序）
    func loadAll(userID: String, category: PendingUploadCategory, sport: SportName) -> [PendingWorkoutUpload] {
        guard let dir = directory(for: userID),
              let files = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }
        let decoder = JSONDecoder()
        let uploads = files.compactMap { url -> PendingWorkoutUpload? in
            guard url.pathExtension == "json",
                  let data = try? Data(contentsOf: url),
                  let upload = try? decoder.decode(PendingWorkoutUpload.self, from: data) else {
                return nil
            }
            return upload
        }
        return uploads
            .filter { $0.category == category && $0.sport == sport }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// 待上传数量（入口按钮角标）
    func pendingCount(userID: String, category: PendingUploadCategory, sport: SportName) -> Int {
        loadAll(userID: userID, category: category, sport: sport).count
    }

    // MARK: - 重传

    /// 重新上传：用原 endpoint + 原 body 再 POST 一次。
    /// 服务端按 client_upload_id 幂等去重，成功后删除本地文件。
    /// 重传只关心成败，不处理结算 body（首传时已展示过结算弹窗）。
    func retry(_ upload: PendingWorkoutUpload, completion: @escaping (Bool) -> Void) {
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        let request = APIRequest(
            path: upload.endpointPath,
            method: .post,
            headers: headers,
            body: upload.body,
            requiresAuth: true
        )
        NetworkService.sendRequest(
            with: request,
            decodingType: EmptyResponse.self,
            showLoadingToast: true,
            showErrorToast: true
        ) { [weak self] result in
            switch result {
            case .success:
                self?.remove(id: upload.id, userID: upload.userID)
                DispatchQueue.main.async { completion(true) }
            case .failure:
                DispatchQueue.main.async { completion(false) }
            }
        }
    }
}
