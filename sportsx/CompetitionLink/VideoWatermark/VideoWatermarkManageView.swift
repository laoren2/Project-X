//
//  VideoWatermarkManageView.swift
//  sportsx
//
//  任务级别操作在管理页完成；资源页仅负责按任务查看与删除本地文件。
//

import SwiftUI
import Photos
import UIKit
import os

struct VideoWatermarkManageView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var manager = VideoWatermarkTaskManager.shared
    @ObservedObject private var userManager = UserManager.shared
    @State private var selection = 0

    private var userID: String { userManager.user.userID }
    private var tasks: [VideoWatermarkTask] {
        selection == 0 ? manager.activeTasks(for: userID) : manager.completedTasks(for: userID)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { appState.navigationManager.removeLast() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.secondText)
                        .frame(width: 44, height: 32)
                }

                Spacer()

                Text("video_watermark.manage.title")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.secondText)

                Spacer()

                Button(action: { appState.navigationManager.append(.videoWatermarkResourceView) }) {
                    Image(systemName: "externaldrive")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.secondText)
                        .frame(width: 44, height: 32)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)

            Picker("video_watermark.manage.tab", selection: $selection) {
                Text("video_watermark.manage.processing").tag(0)
                Text("video_watermark.manage.completed").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            if tasks.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "video")
                        .font(.system(size: 34))
                        .foregroundStyle(Color.secondText)
                    Text("video_watermark.manage.empty")
                        .foregroundStyle(Color.secondText)
                    Spacer()
                }
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(tasks) { task in
                            VideoWatermarkTaskCard(task: task, isActiveList: selection == 0)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .onFirstAppear {
            manager.markNewTasksAsSeen(for: userID)
        }
    }
}

private struct VideoWatermarkTaskCard: View {
    let task: VideoWatermarkTask
    let isActiveList: Bool
    @ObservedObject private var manager = VideoWatermarkTaskManager.shared
    @State private var showShare = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(task.workout.sport.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .padding(10)
                    .background(Color.orange.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(LocalizedStringKey(task.displayTitleKey)).font(.headline)
                        Spacer()
                        Text(LocalizedStringKey(statusKey(task.status)))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(statusColor(task.status))
                    }
                    HStack(spacing: 5) {
                        Text((task.completedAt ?? task.createdAt).formatted(date: .abbreviated, time: .shortened))
                        if task.status == .succeeded {
                            Text("·")
                            Text(completedFormatSummary)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(Color.secondText)
                }
            }
            if task.status == .processing || task.status == .waiting || task.status == .paused {
                ProgressView(value: task.status == .waiting ? 0 : task.progress)
                    .tint(Color.orange)
                if task.status == .waiting {
                    Text("video_watermark.status.waiting_hint")
                        .font(.caption)
                        .foregroundStyle(Color.secondText)
                } else if task.status == .processing, let stage = task.stage {
                    let stageString = "video_watermark.stage.\(stage.rawValue)"
                    Text(LocalizedStringKey(stageString))
                        .font(.caption)
                        .foregroundStyle(Color.secondText)
                }
            }
            if let failure = task.failureMessage {
                Text(LocalizedStringKey(failure))
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            actionRow
        }
        .padding(14)
        .background(Color.secondBackground, in: RoundedRectangle(cornerRadius: 14))
        .sheet(isPresented: $showShare) {
            if FileManager.default.fileExists(atPath: manager.outputURL(for: task).path) {
                VideoWatermarkShareSheet(items: [manager.outputURL(for: task)])
            }
        }
    }

    private var completedFormatSummary: String {
        let format = task.outputFormat
        let resolution: String
        switch format.resolution {
        case .p720: resolution = "720p"
        case .p1080: resolution = "1080p"
        case .p2k: resolution = "2K"
        case .p4k: resolution = "4K"
        }
        return "\(resolution) · \(format.frameRate.rawValue)fps · \(format.dynamicRange.rawValue.uppercased())"
    }

    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: 10) {
            if isActiveList {
                switch task.status {
                case .processing:
                    taskButton("video_watermark.action.pause", icon: "pause.fill") { manager.pause(taskID: task.id) }
                    taskButton("video_watermark.action.cancel", icon: "xmark") { manager.cancel(taskID: task.id) }
                case .paused:
                    taskButton("video_watermark.action.continue", icon: "play.fill") { manager.resume(taskID: task.id) }
                    taskButton("video_watermark.action.cancel", icon: "xmark") { manager.cancel(taskID: task.id) }
                case .waiting:
                    taskButton("video_watermark.action.pause", icon: "pause.fill") { manager.pause(taskID: task.id) }
                    taskButton("video_watermark.action.cancel", icon: "xmark") { manager.cancel(taskID: task.id) }
                default:
                    EmptyView()
                }
            } else {
                switch task.status {
                case .succeeded:
                    taskButton("video_watermark.action.save", icon: "square.and.arrow.down") { saveToPhotos() }
                    taskButton("video_watermark.action.share", icon: "square.and.arrow.up") { showShare = true }
                case .failed:
                    taskButton("video_watermark.action.retry", icon: "arrow.clockwise") { manager.resume(taskID: task.id) }
                default:
                    EmptyView()
                }
            }
        }
    }

    private func taskButton(_ title: LocalizedStringKey, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Color.defaultBackground, in: RoundedRectangle(cornerRadius: 9))
        }
        .foregroundStyle(Color.orange)
    }

    private func saveToPhotos() {
        let url = manager.outputURL(for: task)
        guard FileManager.default.fileExists(atPath: url.path) else {
            ToastManager.shared.show(toast: Toast(message: "video_watermark.error.output_missing"))
            return
        }
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                ToastManager.shared.show(toast: Toast(message: "video_watermark.error.photo_permission"))
                return
            }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }
                ToastManager.shared.show(toast: Toast(message: "video_watermark.toast.saved"))
            } catch {
                Logger.videoWatermark.error_public("save result to photos failed: \(error.localizedDescription)")
                ToastManager.shared.show(toast: Toast(message: "video_watermark.error.save_failed"))
            }
        }
    }

    private func statusKey(_ status: VideoWatermarkTaskStatus) -> String {
        String("video_watermark.status.\(status.rawValue)")
    }

    private func statusColor(_ status: VideoWatermarkTaskStatus) -> Color {
        switch status {
        case .processing: return .orange
        case .waiting: return .blue
        case .paused: return .gray
        case .succeeded: return .green
        case .failed: return .red
        }
    }
}

struct VideoWatermarkResourceView: View {
    @ObservedObject private var manager = VideoWatermarkTaskManager.shared
    @ObservedObject private var userManager = UserManager.shared
    @ObservedObject private var navigationManager = NavigationManager.shared
    @State private var pendingDelete: ResourceDeleteTarget?

    private var groups: [(Date, [VideoWatermarkTask])] {
        let grouped = Dictionary(grouping: manager.tasks(for: userManager.user.userID)) {
            Calendar.current.startOfDay(for: $0.createdAt)
        }
        return grouped.map { ($0.key, $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.0 > $1.0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { navigationManager.removeLast() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.secondText)
                        .frame(width: 44, height: 32)
                }
                
                Spacer()
                
                Text("video_watermark.resource.title")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.secondText)
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 32)
                        .foregroundStyle(.clear)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
            
            List {
                ForEach(groups, id: \.0) { day, tasks in
                    Section(day.formatted(date: .abbreviated, time: .omitted)) {
                        ForEach(tasks) { task in
                            resourceTaskSection(task)
                        }
                    }
                }
            }
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .alert(item: $pendingDelete) { target in
            Alert(
                title: Text("video_watermark.resource.delete.title"),
                message: Text(target.messageKey),
                primaryButton: .destructive(Text("video_watermark.action.delete")) { performDelete(target) },
                secondaryButton: .cancel()
            )
        }
    }

    @ViewBuilder
    private func resourceTaskSection(_ task: VideoWatermarkTask) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(task.displayTitleKey)).font(.subheadline.weight(.semibold))
            Text((task.completedAt ?? task.createdAt).formatted(date: .numeric, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        if FileManager.default.fileExists(atPath: manager.sourceURL(for: task).path) {
            resourceRow(task: task, kind: .source, title: "video_watermark.resource.source")
        }
        if FileManager.default.fileExists(atPath: manager.outputURL(for: task).path) {
            resourceRow(task: task, kind: .output, title: "video_watermark.resource.output")
        }
        Button(role: .destructive) { pendingDelete = .task(task) } label: {
            Label("video_watermark.resource.delete_task", systemImage: "trash")
                .foregroundStyle(Color.red)
        }
        .disabled(task.status == .processing)
    }

    private func resourceRow(task: VideoWatermarkTask, kind: ResourceDeleteTarget.Kind, title: LocalizedStringKey) -> some View {
        let url = kind == .source ? manager.sourceURL(for: task) : manager.outputURL(for: task)
        return HStack {
            Image(systemName: kind == .source ? "video" : "video.fill")
                .foregroundStyle(Color.orange)
            VStack(alignment: .leading) {
                Text(title)
                Text(ByteCountFormatter.string(fromByteCount: fileByteCount(url), countStyle: .file))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive) { pendingDelete = ResourceDeleteTarget(task: task, kind: kind) } label: {
                Image(systemName: "trash")
                    .foregroundStyle(Color.red)
            }
            .disabled(task.status == .processing)
        }
    }

    private func fileByteCount(_ url: URL) -> Int64 {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
    }

    private func performDelete(_ target: ResourceDeleteTarget) {
        switch target.kind {
        case .source: manager.deleteSource(for: target.task.id)
        case .output: manager.deleteOutput(for: target.task.id)
        case .task: manager.deleteTask(id: target.task.id)
        }
    }
}

private struct ResourceDeleteTarget: Identifiable {
    enum Kind { case source, output, task }
    let task: VideoWatermarkTask
    let kind: Kind
    var id: String { "\(task.id.uuidString)-\(String(describing: kind))" }
    init(task: VideoWatermarkTask, kind: Kind) { self.task = task; self.kind = kind }
    static func task(_ task: VideoWatermarkTask) -> ResourceDeleteTarget { ResourceDeleteTarget(task: task, kind: .task) }
    var messageKey: LocalizedStringKey {
        switch kind {
        case .source: return "video_watermark.resource.delete_source_message"
        case .output: return "video_watermark.resource.delete_output_message"
        case .task: return "video_watermark.resource.delete_task_message"
        }
    }
}

struct VideoWatermarkShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
