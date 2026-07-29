//
//  VideoWatermarkBackgroundCoordinator.swift
//  sportsx
//
//  iOS 26 将用户发起的视频导出交给 Continued Processing；低版本由任务管理器尽力续跑。
//

import BackgroundTasks
import Foundation
import UIKit
import os

@MainActor
final class VideoWatermarkBackgroundCoordinator {
    static let shared = VideoWatermarkBackgroundCoordinator()

    private static let continuedProcessingPrefix = "com.valbara.sporreer.videoWatermark"
    private var registeredTaskIDs: Set<UUID> = []

    // 用类型擦除保存仅 iOS 26 提供的系统任务，避免抬高整个 App 的部署版本。
    private var continuedTasks: [UUID: Any] = [:]
    private var taskStartedAt: [UUID: Date] = [:]
    private var taskGPURequested: [UUID: Bool] = [:]

    private init() {}

    /// Continued Processing 必须由用户操作触发，并会先在前台启动、按需延续到后台。
    /// 使用 `.fail` 使“不能立即开始”成为可见的失败，而不是被系统排队到未知时间后才接管。
    func submit(taskID: UUID) -> Bool {
        guard #available(iOS 26.0, *) else { return false }
        let identifier = Self.identifier(for: taskID)
        if !registeredTaskIDs.contains(taskID) {
            // Continued Processing 要求注册和提交都使用同一个完整、唯一的任务 ID。
            let registered = BGTaskScheduler.shared.register(
                forTaskWithIdentifier: identifier,
                using: nil
            ) { task in
                guard let continuedTask = task as? BGContinuedProcessingTask else {
                    task.setTaskCompleted(success: false)
                    return
                }
                Task { @MainActor in
                    VideoWatermarkBackgroundCoordinator.shared.begin(taskID: taskID, systemTask: continuedTask)
                }
            }
            guard registered else {
                Logger.videoWatermark.error_public("video watermark background task registration failed")
                Logger.videoWatermark.debug_public("register continued task \(taskID.uuidString) rejected")
                return false
            }
            registeredTaskIDs.insert(taskID)
            Logger.videoWatermark.debug_public("registered continued task \(taskID.uuidString)")
        }
        let request = BGContinuedProcessingTaskRequest(
            identifier: identifier,
            title: NSLocalizedString("video_watermark.background.title", comment: ""),
            subtitle: NSLocalizedString("video_watermark.background.subtitle", comment: "")
        )
        request.strategy = .fail
        let gpuSupported = BGTaskScheduler.supportedResources.contains(.gpu)
        if gpuSupported {
            request.requiredResources = .gpu
        }
        taskGPURequested[taskID] = gpuSupported
        do {
            try BGTaskScheduler.shared.submit(request)
            Logger.videoWatermark.debug_public("submitted continued task \(taskID.uuidString): strategy=fail, gpuRequested=\(gpuSupported), appState=\(Self.appStateName), lowPower=\(ProcessInfo.processInfo.isLowPowerModeEnabled), thermal=\(Self.thermalStateName)")
            return true
        } catch {
            taskGPURequested.removeValue(forKey: taskID)
            Logger.videoWatermark.error_public("video watermark background task submission failed")
            Logger.videoWatermark.debug_public("submit continued task \(taskID.uuidString) failed: \(error.localizedDescription), strategy=fail, gpuSupported=\(gpuSupported), appState=\(Self.appStateName), lowPower=\(ProcessInfo.processInfo.isLowPowerModeEnabled), thermal=\(Self.thermalStateName)")
            return false
        }
    }

    func cancelScheduled(taskID: UUID) {
        guard #available(iOS 26.0, *) else { return }
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.identifier(for: taskID))
        taskGPURequested.removeValue(forKey: taskID)
        taskStartedAt.removeValue(forKey: taskID)
        Logger.videoWatermark.notice_public("video watermark background task cancelled")
        Logger.videoWatermark.debug_public("cancelled scheduled continued task: \(taskID.uuidString)")
    }

    @available(iOS 26.0, *)
    private func begin(taskID: UUID, systemTask: BGContinuedProcessingTask) {
        continuedTasks[taskID] = systemTask
        taskStartedAt[taskID] = Date()
        systemTask.progress.totalUnitCount = 1_000
        systemTask.progress.completedUnitCount = 0
        Logger.videoWatermark.notice_public("video watermark background task started")
        Logger.videoWatermark.debug_public("continued task began: \(taskID.uuidString), gpuRequested=\(taskGPURequested[taskID] ?? false), appState=\(Self.appStateName), lowPower=\(ProcessInfo.processInfo.isLowPowerModeEnabled), thermal=\(Self.thermalStateName)")
        systemTask.expirationHandler = { [weak self] in
            Task { @MainActor in
                self?.expire(taskID: taskID)
            }
        }
        VideoWatermarkTaskManager.shared.startScheduledExport(taskID: taskID)
    }

    func updateProgress(taskID: UUID, progress: Double) {
        guard #available(iOS 26.0, *), let task = continuedTasks[taskID] as? BGContinuedProcessingTask else { return }
        task.progress.completedUnitCount = Int64((min(max(progress, 0), 1) * 1_000).rounded())
    }

    func complete(taskID: UUID, success: Bool) {
        guard #available(iOS 26.0, *), let task = continuedTasks.removeValue(forKey: taskID) as? BGContinuedProcessingTask else { return }
        let runtime = Date().timeIntervalSince(taskStartedAt.removeValue(forKey: taskID) ?? Date())
        let gpuRequested = taskGPURequested.removeValue(forKey: taskID) ?? false
        Logger.videoWatermark.notice_public("video watermark background task completed")
        Logger.videoWatermark.debug_public("continued task completed: \(taskID.uuidString), success=\(success), runtime=\(String(format: "%.2f", runtime))s, progress=\(task.progress.completedUnitCount)/\(task.progress.totalUnitCount), gpuRequested=\(gpuRequested)")
        task.setTaskCompleted(success: success)
    }

    @available(iOS 26.0, *)
    private func expire(taskID: UUID) {
        guard let task = continuedTasks[taskID] as? BGContinuedProcessingTask else { return }
        let runtime = Date().timeIntervalSince(taskStartedAt[taskID] ?? Date())
        Logger.videoWatermark.error_public("video watermark background task expired")
        Logger.videoWatermark.debug_public("continued task expired by system: \(taskID.uuidString), runtime=\(String(format: "%.2f", runtime))s, progress=\(task.progress.completedUnitCount)/\(task.progress.totalUnitCount), gpuRequested=\(taskGPURequested[taskID] ?? false), appState=\(Self.appStateName), lowPower=\(ProcessInfo.processInfo.isLowPowerModeEnabled), thermal=\(Self.thermalStateName). iOS does not expose a more specific expiration reason.")
        complete(taskID: taskID, success: false)
        VideoWatermarkTaskManager.shared.handleSystemExpiration(taskID: taskID)
    }

    private static var appStateName: String {
        switch UIApplication.shared.applicationState {
        case .active: return "active"
        case .inactive: return "inactive"
        case .background: return "background"
        @unknown default: return "unknown"
        }
    }

    private static var thermalStateName: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    private static func identifier(for taskID: UUID) -> String {
        "\(continuedProcessingPrefix).\(taskID.uuidString)"
    }
}
