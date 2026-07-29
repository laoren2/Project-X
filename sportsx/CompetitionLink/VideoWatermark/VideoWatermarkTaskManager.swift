//
//  VideoWatermarkTaskManager.swift
//  sportsx
//
//  任务队列只允许同时导出一个视频；任务和资源均落在 Application Support。
//

import Foundation
import Combine
import os
import UIKit
import Photos

@MainActor
final class VideoWatermarkTaskManager: ObservableObject {
    static let shared = VideoWatermarkTaskManager()
    private static let unreadTaskUserIDsDefaultsKey = "videoWatermark.unreadTaskUserIDs"

    @Published private(set) var tasks: [VideoWatermarkTask] = []
    @Published private(set) var activeTaskID: UUID?
    @Published private var unreadTaskUserIDs: Set<String>

    private var exportTask: Task<Void, Never>?
    private var exportCancellation: VideoWatermarkExportCancellation?
    private var pausingTaskIDs: Set<UUID> = []
    private var deletingActiveTaskIDs: Set<UUID> = []
    private var fallbackBackgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    private let defaults = UserDefaults.standard

    private init() {
        unreadTaskUserIDs = Set(UserDefaults.standard.stringArray(forKey: Self.unreadTaskUserIDsDefaultsKey) ?? [])
        loadAllTasks()
    }

    func applicationDidEnterBackground() {
        guard #unavailable(iOS 26.0), activeTaskID != nil, fallbackBackgroundTaskID == .invalid else { return }
        fallbackBackgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "VideoWatermarkExport") { [weak self] in
            Task { @MainActor in
                self?.fallbackBackgroundTaskExpired()
            }
        }
        Logger.videoWatermark.debug_public("started fallback background time")
    }

    func applicationDidBecomeActive() {
        endFallbackBackgroundTask()
        startNextIfNeeded()
    }

    // MARK: - Query

    func tasks(for userID: String) -> [VideoWatermarkTask] {
        tasks.filter { $0.userID == userID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func activeTasks(for userID: String) -> [VideoWatermarkTask] {
        tasks(for: userID).filter { $0.status.isActive }
    }

    func completedTasks(for userID: String) -> [VideoWatermarkTask] {
        tasks(for: userID).filter { $0.status.isTerminal }
    }

    func hasUnseenNewTask(for userID: String) -> Bool {
        !userID.isEmpty && unreadTaskUserIDs.contains(userID)
    }

    func markNewTasksAsSeen(for userID: String) {
        guard unreadTaskUserIDs.remove(userID) != nil else { return }
        defaults.set(unreadTaskUserIDs.sorted(), forKey: Self.unreadTaskUserIDsDefaultsKey)
    }

    func sourceURL(for task: VideoWatermarkTask) -> URL {
        taskDirectory(for: task).appendingPathComponent(task.media.sourceFileName)
    }

    func outputURL(for task: VideoWatermarkTask) -> URL {
        taskDirectory(for: task).appendingPathComponent(task.media.outputFileName)
    }

    func thumbnailURL(for task: VideoWatermarkTask) -> URL {
        taskDirectory(for: task).appendingPathComponent("thumbnail.jpg")
    }

    func resourceByteCount(for task: VideoWatermarkTask) -> Int64 {
        fileByteCount(sourceURL(for: task)) + fileByteCount(outputURL(for: task)) + fileByteCount(thumbnailURL(for: task))
    }

    // MARK: - Create / queue

    /// 相册资源只保存引用；仅兼容路径传入已经导入 App 临时目录的完整文件。
    func createTask(_ task: VideoWatermarkTask, importedSourceURL: URL?) async throws {
        var storedTask = task
        // 同时只运行一项；后来创建的任务明确以暂停状态等待用户继续。
        if activeTaskID != nil {
            storedTask.status = .paused
        }
        let directory = taskDirectory(for: task)
        let destination = sourceURL(for: task)
        var persistenceMode = "photo_reference"
        if let importedSourceURL {
            let sourceByteCount = fileByteCount(importedSourceURL)
            let copyStartedAt = Date()
            Logger.videoWatermark.debug_public("persisting fallback imported video: task=\(task.id.uuidString), bytes=\(sourceByteCount), source=\(importedSourceURL.lastPathComponent)")
            persistenceMode = try await Task.detached(priority: .userInitiated) { () throws -> String in
                let manager = FileManager.default
                try manager.createDirectory(at: directory, withIntermediateDirectories: true)
                if manager.fileExists(atPath: destination.path) {
                    try manager.removeItem(at: destination)
                }
                do {
                    try manager.moveItem(at: importedSourceURL, to: destination)
                    return "moved"
                } catch {
                    try manager.copyItem(at: importedSourceURL, to: destination)
                    return "copied_after_move_failed"
                }
            }.value
            excludeFromBackup(destination)
            Logger.videoWatermark.debug_public("persisted fallback source in \(String(format: "%.2f", Date().timeIntervalSince(copyStartedAt)))s")
        } else {
            guard task.photoAssetReference != nil else { throw VideoWatermarkSourceError.missingReference }
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        tasks.append(storedTask)
        persist(storedTask)
        markNewTaskAsUnseen(for: storedTask.userID)
        Logger.videoWatermark.notice_public("video watermark task created")
        Logger.videoWatermark.debug_public("created task \(task.id.uuidString), status: \(storedTask.status.rawValue), persistence=\(persistenceMode)")
        startNextIfNeeded()
    }

    func pause(taskID: UUID) {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return }
        if task.status == .waiting {
            if activeTaskID == taskID {
                VideoWatermarkBackgroundCoordinator.shared.cancelScheduled(taskID: taskID)
                activeTaskID = nil
            }
            update(taskID: taskID, status: .paused, progress: 0, failureMessage: nil)
            return
        }
        guard activeTaskID == taskID else { return }
        Logger.videoWatermark.notice_public("video watermark task pause requested")
        Logger.videoWatermark.debug_public("pause requested for task \(taskID.uuidString)")
        pausingTaskIDs.insert(taskID)
        // 先切换 UI 状态并停止进度回调；实际编码循环会在下一次取消检查时清理输出并结束。
        update(taskID: taskID, status: .paused, progress: task.progress, failureMessage: nil)
        exportCancellation?.cancel()
        exportTask?.cancel()
    }

    func resume(taskID: UUID) {
        guard !pausingTaskIDs.contains(taskID) else {
            Logger.videoWatermark.debug_public("resume ignored while export cancellation is still draining: \(taskID.uuidString)")
            return
        }
        guard let index = tasks.firstIndex(where: { $0.id == taskID }),
              tasks[index].status == .paused || tasks[index].status == .failed else { return }
        guard fileManager.fileExists(atPath: sourceURL(for: tasks[index]).path) || tasks[index].photoAssetReference != nil else {
            update(taskID: taskID, status: .failed, progress: 0, failureMessage: "video_watermark.error.source_missing")
            return
        }
        tasks[index].status = .waiting
        tasks[index].progress = 0
        tasks[index].failureMessage = nil
        tasks[index].outputDeleted = false
        persist(tasks[index])
        Logger.videoWatermark.notice_public("video watermark task queued")
        Logger.videoWatermark.debug_public("queued task \(taskID.uuidString)")
        startNextIfNeeded()
    }

    /// 取消表示删除任务及它拥有的资源；处理中任务会先请求取消，再在导出回调删除。
    func cancel(taskID: UUID) {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return }
        if activeTaskID == taskID {
            deletingActiveTaskIDs.insert(taskID)
            if tasks.first(where: { $0.id == taskID })?.status == .waiting {
                VideoWatermarkBackgroundCoordinator.shared.cancelScheduled(taskID: taskID)
                activeTaskID = nil
                deletingActiveTaskIDs.remove(taskID)
                deleteTask(task, allowActive: false)
                startNextIfNeeded()
                return
            }
            pausingTaskIDs.insert(taskID)
            exportCancellation?.cancel()
            exportTask?.cancel()
            return
        }
        deleteTask(task, allowActive: false)
    }

    // MARK: - Resource / task deletion

    /// 处理中任务及其资源不允许删除。等待、暂停、失败任务删原片等同删除任务。
    func deleteSource(for taskID: UUID) {
        guard let task = tasks.first(where: { $0.id == taskID }), task.status != .processing else { return }
        if task.status == .waiting || task.status == .paused || task.status == .failed {
            deleteTask(task, allowActive: false)
            return
        }
        removeFile(sourceURL(for: task))
        if deleteTaskIfNoVideoResources(task) { return }
        Logger.videoWatermark.debug_public("deleted source of task \(taskID.uuidString)")
    }

    /// 成功任务删除成片后转失败，使用户可通过重试重新生成。
    func deleteOutput(for taskID: UUID) {
        guard let task = tasks.first(where: { $0.id == taskID }), task.status != .processing else { return }
        removeFile(outputURL(for: task))
        removeFile(thumbnailURL(for: task))
        if deleteTaskIfNoVideoResources(task) { return }
        update(taskID: taskID, status: .failed, progress: 0, failureMessage: "video_watermark.error.output_deleted", outputDeleted: true)
        Logger.videoWatermark.debug_public("deleted output of task \(taskID.uuidString)")
    }

    func deleteTask(id: UUID) {
        guard let task = tasks.first(where: { $0.id == id }), task.status != .processing else { return }
        deleteTask(task, allowActive: false)
    }

    // MARK: - Export lifecycle

    /// iOS 26 的系统任务启动时由 Background Coordinator 调用。
    func startScheduledExport(taskID: UUID) {
        guard activeTaskID == taskID,
              let task = tasks.first(where: { $0.id == taskID }),
              task.status == .waiting else {
            VideoWatermarkBackgroundCoordinator.shared.complete(taskID: taskID, success: false)
            return
        }
        beginExport(task)
    }

    func handleSystemExpiration(taskID: UUID) {
        guard activeTaskID == taskID else { return }
        let task = tasks.first(where: { $0.id == taskID })
        Logger.videoWatermark.error_public("video watermark task expired")
        Logger.videoWatermark.debug_public("system expiration received by export manager: task=\(taskID.uuidString), status=\(task?.status.rawValue ?? "missing"), progress=\(String(format: "%.3f", task?.progress ?? -1)), appState=\(UIApplication.shared.applicationState.rawValue)")
        pausingTaskIDs.insert(taskID)
        exportCancellation?.cancel()
        exportTask?.cancel()
    }

    private func startNextIfNeeded() {
        guard activeTaskID == nil, exportTask == nil else { return }
        guard let next = tasks
            .filter({ $0.status == .waiting })
            .sorted(by: { $0.createdAt < $1.createdAt })
            .first else { return }

        guard fileManager.fileExists(atPath: sourceURL(for: next).path) || next.photoAssetReference != nil else {
            update(taskID: next.id, status: .failed, progress: 0, failureMessage: "video_watermark.error.source_missing")
            startNextIfNeeded()
            return
        }

        activeTaskID = next.id
        // Apple 的 Continued Processing 任务由用户操作立即启动，随后可在 App 进入后台后继续运行。
        if VideoWatermarkBackgroundCoordinator.shared.submit(taskID: next.id) {
            return
        }
        Logger.videoWatermark.warning_public("video watermark background task unavailable; using foreground export")
        Logger.videoWatermark.debug_public("continued task could not start immediately; falling back to foreground-only export: \(next.id.uuidString)")
        beginExport(next)
    }

    private func beginExport(_ task: VideoWatermarkTask) {
        update(taskID: task.id, status: .processing, progress: 0, failureMessage: nil, stage: .preparingSource)
        let source = sourceURL(for: task)
        let output = outputURL(for: task)
        removeFile(output)
        Logger.videoWatermark.notice_public("video watermark task started")
        Logger.videoWatermark.debug_public("start processing task \(task.id.uuidString)")
        if UIApplication.shared.applicationState == .background {
            applicationDidEnterBackground()
        }

        let cancellation = VideoWatermarkExportCancellation()
        exportCancellation = cancellation
        exportTask = Task {
            do {
                var exportTaskModel = task
                if !self.fileManager.fileExists(atPath: source.path) {
                    guard let reference = task.photoAssetReference else { throw VideoWatermarkSourceError.missingReference }
                    try await self.materializePhotoAsset(reference, to: source, taskID: task.id)
                    try Task.checkCancellation()
                    let inspection = try await VideoWatermarkMediaAnalyzer.inspectInBackground(url: source)
                    let refreshedMedia = VideoWatermarkMediaAnalyzer.makeMediaInfo(inspection: inspection)
                    await MainActor.run {
                        VideoWatermarkTaskManager.shared.updateMedia(taskID: task.id, media: refreshedMedia)
                        VideoWatermarkTaskManager.shared.update(taskID: task.id, status: .processing, progress: 0.2, failureMessage: nil, stage: .generating)
                    }
                    exportTaskModel.media = refreshedMedia
                } else {
                    await MainActor.run {
                        VideoWatermarkTaskManager.shared.update(taskID: task.id, status: .processing, progress: 0, failureMessage: nil, stage: .generating)
                    }
                }
                let result = try await VideoWatermarkExportEngine.export(task: exportTaskModel, sourceURL: source, outputURL: output, cancellation: cancellation) { progress in
                    Task { @MainActor in
                        VideoWatermarkTaskManager.shared.updateProgress(taskID: task.id, progress: 0.2 + progress * 0.8)
                    }
                }
                guard !Task.isCancelled else { throw CancellationError() }
                await MainActor.run {
                    VideoWatermarkTaskManager.shared.finishSuccess(taskID: task.id, outputByteCount: result.outputByteCount)
                }
            } catch is CancellationError {
                await MainActor.run {
                    VideoWatermarkTaskManager.shared.finishPaused(taskID: task.id)
                }
            } catch {
                await MainActor.run {
                    VideoWatermarkTaskManager.shared.finishFailure(taskID: task.id, error: error)
                }
            }
        }
    }

    private func finishSuccess(taskID: UUID, outputByteCount: Int64) {
        update(taskID: taskID, status: .succeeded, progress: 1, failureMessage: nil, outputByteCount: outputByteCount, outputDeleted: false, completedAt: Date(), stage: nil)
        VideoWatermarkBackgroundCoordinator.shared.updateProgress(taskID: taskID, progress: 1)
        pausingTaskIDs.remove(taskID)
        activeTaskID = nil
        exportTask = nil
        exportCancellation = nil
        endFallbackBackgroundTask()
        VideoWatermarkBackgroundCoordinator.shared.complete(taskID: taskID, success: true)
        Logger.videoWatermark.notice_public("video watermark task completed")
        Logger.videoWatermark.debug_public("finished export task \(taskID.uuidString)")
        startNextIfNeeded()
    }

    private func finishPaused(taskID: UUID) {
        removeFile(outputURL(forTaskID: taskID))
        pausingTaskIDs.remove(taskID)
        if deletingActiveTaskIDs.remove(taskID) != nil, let task = tasks.first(where: { $0.id == taskID }) {
            deleteTask(task, allowActive: true)
        } else if tasks.contains(where: { $0.id == taskID }) {
            update(taskID: taskID, status: .paused, progress: 0, failureMessage: nil, stage: nil)
        }
        activeTaskID = nil
        exportTask = nil
        exportCancellation = nil
        endFallbackBackgroundTask()
        VideoWatermarkBackgroundCoordinator.shared.complete(taskID: taskID, success: false)
        Logger.videoWatermark.notice_public("video watermark task paused")
        Logger.videoWatermark.debug_public("paused export task \(taskID.uuidString)")
        startNextIfNeeded()
    }

    private func finishFailure(taskID: UUID, error: Error) {
        removeFile(outputURL(forTaskID: taskID))
        pausingTaskIDs.remove(taskID)
        let failureKey: String
        if let validationError = error as? VideoWatermarkValidationError {
            failureKey = validationError.localizedKey
        } else if let sourceError = error as? VideoWatermarkSourceError {
            switch sourceError {
            case .missingReference, .assetUnavailable, .resourceUnavailable:
                failureKey = "video_watermark.error.source_missing"
            case .cannotCreateDestination, .materializationFailed:
                failureKey = "video_watermark.error.source_unavailable"
            }
        } else {
            failureKey = "video_watermark.error.export_failed"
        }
        update(taskID: taskID, status: .failed, progress: 0, failureMessage: failureKey, stage: nil)
        activeTaskID = nil
        exportTask = nil
        exportCancellation = nil
        endFallbackBackgroundTask()
        VideoWatermarkBackgroundCoordinator.shared.complete(taskID: taskID, success: false)
        Logger.videoWatermark.error_public("video watermark task failed")
        Logger.videoWatermark.debug_public("export task \(taskID.uuidString) failed: \(error.localizedDescription)")
        startNextIfNeeded()
    }

    private func updateProgress(taskID: UUID, progress: Double, stage: VideoWatermarkTaskStage? = nil) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }), tasks[index].status == .processing, !pausingTaskIDs.contains(taskID) else { return }
        let clamped = min(max(progress, 0), 0.999)
        guard clamped - tasks[index].progress >= 0.005 else { return }
        tasks[index].progress = clamped
        if let stage { tasks[index].stage = stage }
        tasks[index].updatedAt = Date()
        persist(tasks[index])
        VideoWatermarkBackgroundCoordinator.shared.updateProgress(taskID: taskID, progress: clamped)
    }

    private func update(taskID: UUID, status: VideoWatermarkTaskStatus, progress: Double, failureMessage: String?, outputByteCount: Int64? = nil, outputDeleted: Bool? = nil, completedAt: Date? = nil, stage: VideoWatermarkTaskStage? = nil) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].status = status
        tasks[index].progress = progress
        tasks[index].failureMessage = failureMessage
        tasks[index].stage = stage
        if let outputByteCount { tasks[index].outputByteCount = outputByteCount }
        if let outputDeleted { tasks[index].outputDeleted = outputDeleted }
        if let completedAt { tasks[index].completedAt = completedAt }
        tasks[index].updatedAt = Date()
        persist(tasks[index])
    }

    private func updateMedia(taskID: UUID, media: VideoWatermarkMediaInfo) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].media = media
        tasks[index].updatedAt = Date()
        persist(tasks[index])
    }

    /// 将相册资源直接流式写入任务目录。不会在编辑页或临时目录复制完整原片。
    private func materializePhotoAsset(_ reference: VideoWatermarkPhotoAssetReference, to destination: URL, taskID: UUID) async throws {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [reference.localIdentifier], options: nil)
        guard let asset = result.firstObject else { throw VideoWatermarkSourceError.assetUnavailable }
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first(where: {
            $0.type.rawValue == reference.resourceTypeRawValue && $0.originalFilename == reference.originalFilename
        }) ?? resources.first(where: { $0.type == .fullSizeVideo || $0.type == .video }) else {
            throw VideoWatermarkSourceError.resourceUnavailable
        }

        let partial = destination.appendingPathExtension("partial")
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        removeFile(partial)
        removeFile(destination)
        guard fileManager.createFile(atPath: partial.path, contents: nil) else {
            throw VideoWatermarkSourceError.cannotCreateDestination
        }

        do {
            let handle = try FileHandle(forWritingTo: partial)
            let state = VideoWatermarkPhotoMaterializationState(handle: handle)
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true
            options.progressHandler = { [weak self] value in
                Task { @MainActor in
                    self?.updateProgress(taskID: taskID, progress: min(max(value, 0), 1) * 0.2, stage: .downloadingSource)
                }
            }
            Logger.videoWatermark.debug_public("materializing selected photo asset: task=\(taskID.uuidString), file=\(resource.originalFilename)")

            try await withTaskCancellationHandler(operation: {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    let requestID = PHAssetResourceManager.default().requestData(
                        for: resource,
                        options: options,
                        dataReceivedHandler: { data in
                            state.append(data)
                        },
                        completionHandler: { error in
                            if let finalError = state.finish(error) {
                                continuation.resume(throwing: finalError)
                            } else {
                                continuation.resume(returning: ())
                            }
                        }
                    )
                    state.setRequestID(requestID)
                }
            }, onCancel: {
                state.cancel()
            })
            try Task.checkCancellation()
            try fileManager.moveItem(at: partial, to: destination)
            excludeFromBackup(destination)
            Logger.videoWatermark.debug_public("materialized selected photo asset: task=\(taskID.uuidString), bytes=\(fileByteCount(destination))")
        } catch is CancellationError {
            removeFile(partial)
            removeFile(destination)
            throw CancellationError()
        } catch {
            removeFile(partial)
            removeFile(destination)
            throw VideoWatermarkSourceError.materializationFailed
        }
    }

    // MARK: - Disk

    private func rootDirectory() -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("VideoWatermarks", isDirectory: true)
    }

    private func taskDirectory(for task: VideoWatermarkTask) -> URL {
        rootDirectory()
            .appendingPathComponent(task.userID, isDirectory: true)
            .appendingPathComponent(task.id.uuidString, isDirectory: true)
    }

    private func outputURL(forTaskID taskID: UUID) -> URL {
        guard let task = tasks.first(where: { $0.id == taskID }) else {
            return rootDirectory().appendingPathComponent("missing.mp4")
        }
        return outputURL(for: task)
    }

    private func manifestURL(for task: VideoWatermarkTask) -> URL {
        taskDirectory(for: task).appendingPathComponent("manifest.json")
    }

    private func persist(_ task: VideoWatermarkTask) {
        do {
            try fileManager.createDirectory(at: taskDirectory(for: task), withIntermediateDirectories: true)
            try encoder.encode(task).write(to: manifestURL(for: task), options: .atomic)
            excludeFromBackup(manifestURL(for: task))
        } catch {
            Logger.videoWatermark.error_public("video watermark task persistence failed")
            Logger.videoWatermark.debug_public("persist task \(task.id.uuidString) failed: \(error.localizedDescription)")
        }
    }

    private func markNewTaskAsUnseen(for userID: String) {
        guard !userID.isEmpty else { return }
        unreadTaskUserIDs.insert(userID)
        defaults.set(unreadTaskUserIDs.sorted(), forKey: Self.unreadTaskUserIDsDefaultsKey)
    }

    private func loadAllTasks() {
        let root = rootDirectory()
        guard let userDirectories = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return }
        let decoder = JSONDecoder()
        let recovered = userDirectories.flatMap { userDirectory -> [VideoWatermarkTask] in
            guard let taskDirectories = try? fileManager.contentsOfDirectory(at: userDirectory, includingPropertiesForKeys: nil) else { return [] }
            return taskDirectories.compactMap { directory -> VideoWatermarkTask? in
                let url = directory.appendingPathComponent("manifest.json")
                guard let data = try? Data(contentsOf: url), var task = try? decoder.decode(VideoWatermarkTask.self, from: data) else { return nil }
                let source = directory.appendingPathComponent(task.media.sourceFileName)
                let output = directory.appendingPathComponent(task.media.outputFileName)
                if task.status.isTerminal,
                   !fileManager.fileExists(atPath: source.path),
                   !fileManager.fileExists(atPath: output.path) {
                    Logger.videoWatermark.debug_public("removed recovered empty terminal task \(task.id.uuidString)")
                    removeFile(directory)
                    return nil
                }
                if task.status == .processing {
                    task.status = .paused
                    task.progress = 0
                    task.updatedAt = Date()
                    Logger.videoWatermark.debug_public("recovered interrupted task \(task.id.uuidString)")
                }
                return task
            }
        }
        tasks = recovered
        tasks.forEach(persist)
    }

    private func deleteTask(_ task: VideoWatermarkTask, allowActive: Bool) {
        guard allowActive || task.status != .processing else { return }
        removeFile(taskDirectory(for: task))
        tasks.removeAll { $0.id == task.id }
        Logger.videoWatermark.notice_public("video watermark task deleted")
        Logger.videoWatermark.debug_public("deleted task \(task.id.uuidString)")
    }

    /// 当原片和成片都不存在时，保留 manifest 已无意义；删除整个任务以免留下空任务卡片。
    private func deleteTaskIfNoVideoResources(_ task: VideoWatermarkTask) -> Bool {
        guard !fileManager.fileExists(atPath: sourceURL(for: task).path),
              !fileManager.fileExists(atPath: outputURL(for: task).path) else { return false }
        Logger.videoWatermark.debug_public("all video resources removed; cleaning task \(task.id.uuidString)")
        deleteTask(task, allowActive: false)
        return true
    }

    private func removeFile(_ url: URL) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        do { try fileManager.removeItem(at: url) }
        catch {
            Logger.videoWatermark.error_public("video watermark resource removal failed")
            Logger.videoWatermark.debug_public("remove \(url.lastPathComponent) failed: \(error.localizedDescription)")
        }
    }

    private func fileByteCount(_ url: URL) -> Int64 {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
    }

    private func excludeFromBackup(_ url: URL) {
        var writableURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? writableURL.setResourceValues(values)
    }

    private func fallbackBackgroundTaskExpired() {
        guard let taskID = activeTaskID else { return }
        Logger.videoWatermark.warning_public("video watermark background time expired")
        Logger.videoWatermark.debug_public("fallback background time expired for \(taskID.uuidString)")
        pausingTaskIDs.insert(taskID)
        exportCancellation?.cancel()
        exportTask?.cancel()
        endFallbackBackgroundTask()
    }

    private func endFallbackBackgroundTask() {
        guard fallbackBackgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(fallbackBackgroundTaskID)
        fallbackBackgroundTaskID = .invalid
    }
}

private enum VideoWatermarkSourceError: Error {
    case missingReference
    case assetUnavailable
    case resourceUnavailable
    case cannotCreateDestination
    case materializationFailed
}

/// PhotoKit 的 requestData 支持取消；状态对象同时串行化文件写入与完成回调。
private final class VideoWatermarkPhotoMaterializationState {
    private let lock = NSLock()
    private let handle: FileHandle
    private var requestID: PHAssetResourceDataRequestID?
    private var writeError: Error?
    private var cancelled = false
    private var finished = false

    init(handle: FileHandle) {
        self.handle = handle
    }

    func setRequestID(_ requestID: PHAssetResourceDataRequestID) {
        let shouldCancel: Bool
        lock.lock()
        self.requestID = requestID
        shouldCancel = cancelled
        lock.unlock()
        if shouldCancel {
            PHAssetResourceManager.default().cancelDataRequest(requestID)
        }
    }

    func append(_ data: Data) {
        var requestToCancel: PHAssetResourceDataRequestID?
        lock.lock()
        if !finished, !cancelled, writeError == nil {
            do {
                try handle.write(contentsOf: data)
            } catch {
                writeError = error
                requestToCancel = requestID
            }
        }
        lock.unlock()
        if let requestToCancel {
            PHAssetResourceManager.default().cancelDataRequest(requestToCancel)
        }
    }

    func cancel() {
        let requestToCancel: PHAssetResourceDataRequestID?
        lock.lock()
        cancelled = true
        requestToCancel = requestID
        lock.unlock()
        if let requestToCancel {
            PHAssetResourceManager.default().cancelDataRequest(requestToCancel)
        }
    }

    func finish(_ requestError: Error?) -> Error? {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return CancellationError() }
        finished = true
        do {
            try handle.close()
        } catch {
            writeError = writeError ?? error
        }
        if cancelled { return CancellationError() }
        return writeError ?? requestError
    }
}
