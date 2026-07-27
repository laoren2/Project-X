//
//  VideoWatermarkEditorView.swift
//  sportsx
//
//  视频导入、自动对齐和基础水印布局编辑。
//

import SwiftUI
import PhotosUI
import Photos
import AVFoundation
import UIKit
import UniformTypeIdentifiers
import os

private func videoWatermarkPhotoAuthorizationName(_ status: PHAuthorizationStatus) -> String {
    switch status {
    case .notDetermined: return "notDetermined"
    case .restricted: return "restricted"
    case .denied: return "denied"
    case .authorized: return "authorized"
    case .limited: return "limited"
    @unknown default: return "unknown"
    }
}

struct VideoWatermarkImportedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            // PhotosPicker 的 received.file 生命周期只保证在导入回调可用，必须先变成 App 自有的
            // 临时文件；否则后续 AVFoundation 检查可能读不到轨道，或用户确认后源文件已失效。
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("video_watermark_import_\(UUID().uuidString).\(ext)")
            let receivedByteCount = (try? received.file.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            let copyStartedAt = Date()
            Logger.videoWatermark.notice_public("video import fallback received PhotosPicker file representation: bytes=\(receivedByteCount), file=\(received.file.lastPathComponent)")
            try FileManager.default.copyItem(at: received.file, to: destination)
            let byteCount = (try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            Logger.videoWatermark.notice_public("video import fallback copied PhotosPicker file into app temporary storage: bytes=\(byteCount), elapsed=\(String(format: "%.2f", Date().timeIntervalSince(copyStartedAt)))s")
            return VideoWatermarkImportedVideo(url: destination)
        }
    }
}

private enum VideoWatermarkImportStage {
    case preparing
    case fetching
    case validating
    case aligning

    var titleKey: LocalizedStringKey {
        switch self {
        case .preparing: return "video_watermark.import.preparing"
        case .fetching: return "video_watermark.import.fetching"
        case .validating: return "video_watermark.import.validating"
        case .aligning: return "video_watermark.import.aligning"
        }
    }

    var logName: String {
        switch self {
        case .preparing: return "preparing"
        case .fetching: return "fetching"
        case .validating: return "validating"
        case .aligning: return "aligning"
        }
    }
}

private enum VideoWatermarkEditorImportSource {
    case photoAsset(asset: PHAsset, reference: VideoWatermarkPhotoAssetReference)
    case temporaryFile(URL)
}

/// 优先保留 PhotoKit 资源引用；仅没有 PHAsset 标识的来源才回退为完整文件导入。
private enum VideoWatermarkPhotoImporter {
    typealias ProgressHandler = (VideoWatermarkImportStage, Double?, Bool) -> Void

    static func importVideo(from item: PhotosPickerItem, progress: @escaping ProgressHandler) async throws -> VideoWatermarkEditorImportSource {
        progress(.preparing, nil, false)
        let authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        Logger.videoWatermark.notice_public("video import requested: itemIdentifier=\(item.itemIdentifier ?? "nil"), photoAuthorization=\(videoWatermarkPhotoAuthorizationName(authorization))")
        if let identifier = item.itemIdentifier {
            let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
            if let asset = result.firstObject,
               let resource = PHAssetResource.assetResources(for: asset).first(where: { $0.type == .fullSizeVideo || $0.type == .video }) {
                let reference = VideoWatermarkPhotoAssetReference(
                    localIdentifier: asset.localIdentifier,
                    resourceTypeRawValue: resource.type.rawValue,
                    originalFilename: resource.originalFilename
                )
                Logger.videoWatermark.notice_public("photo import retained PhotoKit reference without materializing source: asset=\(asset.localIdentifier), file=\(resource.originalFilename)")
                return .photoAsset(asset: asset, reference: reference)
            }
            Logger.videoWatermark.warning_public("video import could not resolve PhotosPicker identifier through PhotoKit: identifier=\(identifier), fetched=\(result.count)")
        }

        // 某些来源不会暴露 PHAsset 标识，保留 PhotosPicker 的标准导入作为兼容兜底。
        Logger.videoWatermark.notice_public("photo import falling back to PhotosPicker transferable: no resolvable PHAsset identifier")
        progress(.fetching, nil, false)
        let fetchingStartedAt = Date()
        guard let imported = try await item.loadTransferable(type: VideoWatermarkImportedVideo.self) else {
            throw VideoWatermarkValidationError.invalidFormat
        }
        let byteCount = (try? imported.url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        Logger.videoWatermark.notice_public("video import PhotosPicker transferable ready in \(String(format: "%.2f", Date().timeIntervalSince(fetchingStartedAt)))s, bytes=\(byteCount), file=\(imported.url.lastPathComponent)")
        progress(.fetching, 1, true)
        return .temporaryFile(imported.url)
    }
}

struct VideoWatermarkEditorView: View {
    let workout: VideoWatermarkWorkoutSnapshot
    @ObservedObject private var taskManager = VideoWatermarkTaskManager.shared
    @ObservedObject private var navigationManager = NavigationManager.shared
    @ObservedObject private var userManager = UserManager.shared

    @State private var selectedItem: PhotosPickerItem?
    @State private var showVideoPicker = false
    @State private var isRequestingPhotoLibraryAccess = false
    @State private var importedURL: URL?
    @State private var photoAssetReference: VideoWatermarkPhotoAssetReference?
    @State private var media: VideoWatermarkMediaInfo?
    @State private var previewImage: UIImage?
    @State private var outputFormat = VideoWatermarkOutputFormat(resolution: .p1080, frameRate: .fps30, dynamicRange: .sdr)
    @State private var selectedMetrics: Set<VideoWatermarkMetric> = [.route, .speed, .altitude, .heartRate, .logo]
    @State private var layouts: [VideoWatermarkMetric: VideoWatermarkLayout] = Self.placeholderLayouts
    @State private var maximumContentSizes: [VideoWatermarkMetric: CGSize] = [:]
    @State private var selectedMetric: VideoWatermarkMetric?
    @State private var isImporting = false
    @State private var isCreatingTask = false
    @State private var importStage: VideoWatermarkImportStage = .preparing
    @State private var importProgress: Double?
    @State private var importErrorKey: String?

    // 导入完成前不会展示编辑画布，这组值只用于保持 State 的初始状态完整。
    // 真实初始尺寸会在拿到视频封面画布尺寸后重新计算。
    private static let placeholderLayouts: [VideoWatermarkMetric: VideoWatermarkLayout] = [
        .route: .route, .speed: .speed, .altitude: .altitude, .heartRate: .heartRate, .logo: .logo
    ]

    private static func maximumContentSizes(for media: VideoWatermarkMediaInfo, workout: VideoWatermarkWorkoutSnapshot) -> [VideoWatermarkMetric: CGSize] {
        Dictionary(uniqueKeysWithValues: VideoWatermarkMetric.allCases.map { metric in
            (
                metric,
                VideoWatermarkOverlayRenderer.maximumPreviewContentSize(
                    for: metric,
                    workoutPoints: workout.points,
                    videoTime: media.effectiveVideoStart,
                    videoDuration: media.effectiveDuration,
                    mediaCreationTime: media.creationTime
                )
            )
        })
    }

    private static func defaultLayouts(for media: VideoWatermarkMediaInfo, workout: VideoWatermarkWorkoutSnapshot, maximumContentSizes: [VideoWatermarkMetric: CGSize]) -> [VideoWatermarkMetric: VideoWatermarkLayout] {
        let policy = VideoWatermarkScalePolicy(coverCanvasSize: CGSize(width: media.width, height: media.height))
        return Dictionary(uniqueKeysWithValues: VideoWatermarkMetric.allCases.map { metric in
            var layout = baseLayout(for: metric)
            let contentSize = VideoWatermarkOverlayRenderer.previewContentSize(
                for: metric,
                workoutPoints: workout.points,
                videoTime: media.effectiveVideoStart,
                mediaCreationTime: media.creationTime
            )
            let maximumContentSize = maximumContentSizes[metric] ?? contentSize
            layout.scale = Double(policy.defaultScale(for: metric, contentSize: contentSize, maximumContentSize: maximumContentSize))
            layout = policy.clamped(layout, for: maximumContentSize)
            return (metric, layout)
        })
    }

    private static func baseLayout(for metric: VideoWatermarkMetric) -> VideoWatermarkLayout {
        switch metric {
        case .route: return .route
        case .speed: return .speed
        case .altitude: return .altitude
        case .heartRate: return .heartRate
        case .logo: return .logo
        }
    }

    var body: some View {
        VStack {
            HStack {
                Button(action: { navigationManager.removeLast() }) {
                    Image(systemName: "chevron.left")
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.white)
                
                Spacer()
                
                Text("video_watermark.editor.title")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white)
                
                Spacer()
                
                // 平衡布局的空按钮
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    if let media {
                        preview(image: previewImage, media: media)
                        metricPanel
                        formatPanel(media)
                        Button(action: createTask) {
                            HStack(spacing: 10) {
                                Image("sport_camera2")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20)
                                Text("video_watermark.action.start")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.white)
                            }
                            .padding(.vertical, 15)
                            .frame(maxWidth: .infinity)
                            .background(Capsule().fill(Color.orange))
                        }
                        .disabled(selectedMetrics.isEmpty || isImporting || isCreatingTask)
                    } else {
                        importPlaceholder
                    }
                    if let importErrorKey {
                        Text(LocalizedStringKey(importErrorKey))
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .onValueChange(of: selectedItem) { _, item in
            guard let item else { return }
            importVideo(item)
        }
        .onAppear {
            if !workout.hasHeartRate { selectedMetrics.remove(.heartRate) }
        }
    }

    private var importPlaceholder: some View {
        Button(action: requestPhotoLibraryAccessAndPresentPicker) {
            VStack(spacing: 14) {
                Image(systemName: isImporting || isRequestingPhotoLibraryAccess ? "arrow.down.circle" : "video.badge.plus")
                    .font(.system(size: 42))
                    .foregroundStyle(Color.orange)
                Text(isImporting ? importStage.titleKey : "video_watermark.action.select_video")
                    .font(.system(size: 16, weight: .semibold))
                if isImporting {
                    if let importProgress {
                        ProgressView(value: importProgress)
                            .tint(Color.orange)
                        Text("\(Int((importProgress * 100).rounded()))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color.secondText)
                    } else {
                        ProgressView()
                            .tint(Color.orange)
                    }
                }
                Text(isImporting ? "video_watermark.import.progress_hint" : "video_watermark.import.hint")
                    .font(.footnote)
                    .foregroundStyle(Color.secondText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 260)
            .background(Color.secondBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(isImporting || isRequestingPhotoLibraryAccess)
        .photosPicker(isPresented: $showVideoPicker, selection: $selectedItem, matching: .videos, photoLibrary: .shared())
    }

    private func preview(image: UIImage?, media: VideoWatermarkMediaInfo) -> some View {
        let aspect = CGFloat(media.height) / CGFloat(max(media.width, 1))
        let previewWidth = min(UIScreen.main.bounds.width - 32, 320, 450 / max(aspect, 0.001))
        let previewHeight = previewWidth * aspect
        return VStack(spacing: 10) {
            GeometryReader { geometry in
                let previewSize = CGSize(width: min(geometry.size.width, previewWidth), height: previewHeight)
                ZStack {
                    Group {
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Color.black.overlay {
                                Image(systemName: "video")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }
                    .frame(width: previewSize.width, height: previewSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .contentShape(Rectangle())
                    .onTapGesture { selectedMetric = nil }

                    WatermarkLayoutPreview(
                        metrics: selectedMetrics,
                        layouts: $layouts,
                        selectedMetric: $selectedMetric,
                        maximumContentSizes: maximumContentSizes,
                        media: media,
                        workout: workout
                    )
                        .frame(width: previewSize.width, height: previewSize.height)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: previewHeight)
            .frame(maxWidth: .infinity)

            effectiveRangeBar(media: media)
                .frame(maxWidth: previewWidth)
        }
    }

    private func effectiveRangeBar(media: VideoWatermarkMediaInfo) -> some View {
        let total = max(media.duration, 0.001)
        let start = min(max(media.effectiveVideoStart / total, 0), 1)
        let end = min(max(media.effectiveVideoEnd / total, start), 1)
        let percentage = min(max(media.effectiveDuration / total, 0), 1)
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("video_watermark.effective_range")
                Spacer()
                Text("\(Int((percentage * 100).rounded()))%")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.55))
                    Capsule()
                        .fill(Color.orange)
                        .frame(width: proxy.size.width * (end - start))
                        .offset(x: proxy.size.width * start)
                }
                .overlay(alignment: .topLeading) {
                    Text(TimeDisplay.formattedTime(media.effectiveVideoStart))
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                        .fixedSize()
                        .offset(x: rangeLabelOffset(position: start, labelWidth: 34, containerWidth: proxy.size.width), y: -17)
                }
                .overlay(alignment: .topLeading) {
                    Text(TimeDisplay.formattedTime(media.effectiveVideoEnd))
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                        .fixedSize()
                        .offset(x: rangeLabelOffset(position: end, labelWidth: 34, containerWidth: proxy.size.width), y: -17)
                }
            }
            .padding(.top, 15)
            .frame(height: 21)
        }
        .padding(8)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    private func rangeLabelOffset(position: Double, labelWidth: CGFloat, containerWidth: CGFloat) -> CGFloat {
        min(max(containerWidth * position - labelWidth / 2, 0), max(containerWidth - labelWidth, 0))
    }

    private var metricPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("video_watermark.metric.title")
                .font(.headline)
                .foregroundStyle(Color.secondText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(VideoWatermarkMetric.allCases) { metric in
                        let unavailable = metric == .heartRate && !workout.hasHeartRate
                        let islocked = metric == .logo && !userManager.user.isVip
                        let selected = selectedMetrics.contains(metric)
                        HStack(spacing: 5) {
                            if metric == .logo {
                                Image("single_app_icon")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 15, height: 15)
                            } else {
                                Image(systemName: metric.iconName)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            Text(LocalizedStringKey(metric.titleKey))
                                .font(.system(size: 13, weight: .medium))
                            if islocked {
                                Image("vip_icon")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 15)
                            }
                        }
                        .foregroundStyle(selected ? Color.white : Color.thirdText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(selected ? Color.orange : Color.secondBackground))
                        .opacity(unavailable && !selected ? 0.4 : 1)
                        .exclusiveTouchTapGesture {
                            guard !unavailable else { return }
                            guard !islocked else {
                                navigationManager.append(.subscriptionDetailView)
                                return
                            }
                            if selected { selectedMetrics.remove(metric) }
                            else { selectedMetrics.insert(metric) }
                            if !selectedMetrics.contains(metric), selectedMetric == metric { selectedMetric = nil }
                        }
                        .disabled(unavailable)
                    }
                }
            }
        }
    }

    private func formatPanel(_ media: VideoWatermarkMediaInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("video_watermark.format.title").font(.headline)
            Text("video_watermark.format.input")
            Text("\(media.codec.uppercased()) · \(media.width)×\(media.height) · \(Int(media.nominalFrameRate.rounded()))fps · \(media.container.uppercased())")
            Text("video_watermark.format.output")
            formatResolutionGroup(media)
            formatFrameRateGroup(media)
            formatDynamicRangeGroup(media)
            Text("video_watermark.format.effective \(TimeDisplay.formattedTime(media.effectiveDuration))")
                .foregroundStyle(Color.secondText)
        }
        .font(.footnote)
        .foregroundStyle(Color.secondText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.secondBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    private static func defaultOutputFormat(for media: VideoWatermarkMediaInfo) -> VideoWatermarkOutputFormat {
        let sourceLongEdge = max(media.width, media.height)
        let resolution = VideoWatermarkOutputResolution.allCases
            .filter { Int($0.longEdge) <= sourceLongEdge && !$0.requiresVip }
            .last ?? .p720
        return VideoWatermarkOutputFormat(resolution: resolution, frameRate: .fps30, dynamicRange: .sdr)
    }

    private func formatResolutionGroup(_ media: VideoWatermarkMediaInfo) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("video_watermark.format.resolution.title").font(.caption.weight(.semibold))
            HStack(spacing: 8) {
                ForEach(VideoWatermarkOutputResolution.allCases) { option in
                    let available = Int(option.longEdge) <= max(media.width, media.height)
                    formatCapsule(title: option.displayTitle, selected: outputFormat.resolution == option, available: available, locked: option.requiresVip && !userManager.user.isVip) {
                        outputFormat.resolution = option
                    }
                }
            }
        }
    }

    private func formatFrameRateGroup(_ media: VideoWatermarkMediaInfo) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("video_watermark.format.frame_rate.title").font(.caption.weight(.semibold))
            HStack(spacing: 8) {
                ForEach(VideoWatermarkOutputFrameRate.allCases) { option in
                    let available = media.nominalFrameRate <= 0 || media.nominalFrameRate >= option.minimumInputFrameRate
                    formatCapsule(title: option.displayTitle, selected: outputFormat.frameRate == option, available: available, locked: option.requiresVip && !userManager.user.isVip) {
                        outputFormat.frameRate = option
                    }
                }
            }
        }
    }

    private func formatDynamicRangeGroup(_ media: VideoWatermarkMediaInfo) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("video_watermark.format.dynamic_range.title").font(.caption.weight(.semibold))
            HStack(spacing: 8) {
                ForEach(VideoWatermarkOutputDynamicRange.allCases) { option in
                    let available = option == .sdr || media.supportsHDR
                    formatCapsule(title: option.displayTitle, selected: outputFormat.dynamicRange == option, available: available, locked: option.requiresVip && !userManager.user.isVip) {
                        outputFormat.dynamicRange = option
                    }
                }
            }
        }
    }

    private func formatCapsule(title: String, selected: Bool, available: Bool, locked: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(title)
            if locked {
                Image("vip_icon_on")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 15)
            }
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(selected ? Color.white : Color.thirdText)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(selected ? Color.orange : Color.defaultBackground))
        .opacity(available ? 1 : 0.35)
        .exclusiveTouchTapGesture {
            guard available else { return }
            if locked { navigationManager.append(.subscriptionDetailView) }
            else { action() }
        }
    }

    private func requestPhotoLibraryAccessAndPresentPicker() {
        isRequestingPhotoLibraryAccess = true
        Task {
            let before = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            let after: PHAuthorizationStatus
            if before == .notDetermined {
                Logger.videoWatermark.notice_public("video import requesting Photos read-write authorization")
                after = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            } else {
                after = before
            }
            //Logger.videoWatermark.notice_public("video import Photos authorization resolved: before=\(videoWatermarkPhotoAuthorizationName(before)), after=\(videoWatermarkPhotoAuthorizationName(after))")
            await MainActor.run {
                isRequestingPhotoLibraryAccess = false
                guard after == .authorized || after == .limited else {
                    ToastManager.shared.show(toast: Toast(message: "video_watermark.error.photo_read_permission"))
                    return
                }
                showVideoPicker = true
            }
        }
    }

    private func importVideo(_ item: PhotosPickerItem) {
        isImporting = true
        importErrorKey = nil
        importStage = .preparing
        importProgress = nil
        let startedAt = Date()
        Task {
            var temporaryURL: URL?
            do {
                let source = try await VideoWatermarkPhotoImporter.importVideo(from: item) { stage, progress, isDeterminate in
                    Task { @MainActor in
                        updateImportProgress(stage: stage, progress: progress, isDeterminate: isDeterminate)
                    }
                }
                updateImportProgress(stage: .validating, progress: 0.86, isDeterminate: true)
                let inspection: VideoWatermarkVideoInspection
                let coverImage: UIImage?
                let localURL: URL?
                let reference: VideoWatermarkPhotoAssetReference?
                switch source {
                case let .photoAsset(asset, assetReference):
                    if let inspected = await VideoWatermarkMediaAnalyzer.inspectPhotoAssetInBackground(asset: asset, reference: assetReference) {
                        inspection = inspected
                    } else {
                        inspection = try VideoWatermarkMediaAnalyzer.inspect(asset: asset, reference: assetReference)
                    }
                    coverImage = await VideoWatermarkMediaAnalyzer.makeCoverImageInBackground(for: asset)
                    localURL = nil
                    reference = assetReference
                case let .temporaryFile(url):
                    temporaryURL = url
                    inspection = try await VideoWatermarkMediaAnalyzer.inspectInBackground(url: url)
                    coverImage = await VideoWatermarkMediaAnalyzer.makeCoverImageInBackground(url: url, at: 0)
                    localURL = url
                    reference = nil
                }
                updateImportProgress(stage: .aligning, progress: 0.94, isDeterminate: true)
                let info = try VideoWatermarkMediaAnalyzer.makeMediaInfo(inspection: inspection, workout: workout)
                await MainActor.run {
                    importedURL = localURL
                    photoAssetReference = reference
                    media = info
                    previewImage = coverImage
                    let maximumContentSizes = Self.maximumContentSizes(for: info, workout: workout)
                    self.maximumContentSizes = maximumContentSizes
                    layouts = Self.defaultLayouts(for: info, workout: workout, maximumContentSizes: maximumContentSizes)
                    outputFormat = Self.defaultOutputFormat(for: info)
                    selectedMetric = nil
                    isImporting = false
                    importProgress = 1
                    Logger.videoWatermark.notice_public("video import complete in \(String(format: "%.2f", Date().timeIntervalSince(startedAt)))s: \(info.codec) \(info.width)x\(info.height), duration=\(String(format: "%.2f", info.duration))s, effectiveStart=\(String(format: "%.2f", info.effectiveVideoStart))s, effectiveDuration=\(String(format: "%.2f", info.effectiveDuration))s, cover=\(coverImage == nil ? "unavailable" : "ready")")
                }
            } catch let error as VideoWatermarkValidationError {
                if let temporaryURL { try? FileManager.default.removeItem(at: temporaryURL) }
                await MainActor.run {
                    importErrorKey = error.localizedKey
                    isImporting = false
                    ToastManager.shared.show(toast: Toast(message: error.localizedKey))
                }
            } catch {
                if let temporaryURL { try? FileManager.default.removeItem(at: temporaryURL) }
                await MainActor.run {
                    importErrorKey = "video_watermark.error.import_failed"
                    isImporting = false
                    Logger.videoWatermark.error_public("video import failed: \(error.localizedDescription)")
                    ToastManager.shared.show(toast: Toast(message: "video_watermark.error.import_failed"))
                }
            }
        }
    }

    @MainActor
    private func updateImportProgress(stage: VideoWatermarkImportStage, progress: Double?, isDeterminate: Bool) {
        if stage != importStage {
            Logger.videoWatermark.notice_public("video import stage: \(stage.logName)")
            importStage = stage
        }
        importProgress = isDeterminate ? progress.map { min(max($0, 0), 1) } : nil
    }

    private func createTask() {
        guard let media, !selectedMetrics.isEmpty else { return }
        guard importedURL != nil || photoAssetReference != nil else { return }
        guard userManager.user.isVip || (!outputFormat.resolution.requiresVip && !outputFormat.frameRate.requiresVip && !outputFormat.dynamicRange.requiresVip) else {
            navigationManager.append(.subscriptionDetailView)
            return
        }
        let userID = UserManager.shared.user.userID
        guard !userID.isEmpty else {
            ToastManager.shared.show(toast: Toast(message: "toast.no_login"))
            return
        }
        let task = VideoWatermarkTask(userID: userID, workout: workout, media: media, photoAssetReference: photoAssetReference, outputFormat: outputFormat, selectedMetrics: selectedMetrics, layouts: layouts)
        isCreatingTask = true
        Task {
            do {
                try await taskManager.createTask(task, importedSourceURL: importedURL)
                if let importedURL { try? FileManager.default.removeItem(at: importedURL) }
                ToastManager.shared.show(toast: Toast(message: "video_watermark.toast.queued"))
                navigationManager.removeLast()
            } catch {
                Logger.videoWatermark.error_public("create task failed: \(error.localizedDescription)")
                ToastManager.shared.show(toast: Toast(message: "video_watermark.error.create_failed"))
                isCreatingTask = false
            }
        }
    }
}

/// 将水印的视觉长边统一映射到视频封面短边的一个比例区间。
///
/// `scale` 仍是渲染器使用的内容倍数；策略仅负责把“封面上的视觉尺寸”换算为该倍数。
/// 数字水印以主数字字号为基准，而非整段文字宽度；当前文字尺寸只用于虚线框，
/// 有效视频内的最大文字尺寸则用于限制滑杆上限和拖拽边界。
private struct VideoWatermarkScalePolicy {
    private let coverCanvasSize: CGSize

    private let routeMinimumExtentRatio: CGFloat = 0.20
    private let logoMinimumExtentRatio: CGFloat = 0.30
    private let maximumExtentRatio: CGFloat = 0.60
    private let defaultRangeProgress: CGFloat = 1.0 / 3.0
    private let baseMetricFontSize: CGFloat = 26
    private let minimumMetricFontRatio: CGFloat = 0.045
    private let defaultMetricFontRatio: CGFloat = 0.065
    private let maximumMetricFontRatio: CGFloat = 0.09

    init(coverCanvasSize: CGSize) {
        self.coverCanvasSize = coverCanvasSize
    }

    func range(for metric: VideoWatermarkMetric, contentSize: CGSize, maximumContentSize: CGSize) -> ClosedRange<CGFloat> {
        let coverShortSide = min(coverCanvasSize.width, coverCanvasSize.height)
        guard coverShortSide.isFinite, coverShortSide > 0 else {
            return 1...1
        }

        switch metric {
        case .speed, .altitude, .heartRate:
            // 三种数据水印的主数字均使用 26pt 基础字体，因此用字号换算 scale，
            // 使不同文本长度仍保持一致的数字视觉层级。
            let minimum = coverShortSide * minimumMetricFontRatio / baseMetricFontSize
            let preferredMaximum = coverShortSide * maximumMetricFontRatio / baseMetricFontSize
            let safeWidth = max(maximumContentSize.width, contentSize.width)
            let widthLimitedMaximum = safeWidth > 0 ? coverShortSide * maximumExtentRatio / safeWidth : preferredMaximum
            let maximum = min(preferredMaximum, widthLimitedMaximum)
            return min(minimum, maximum)...maximum
        case .route, .logo:
            let contentLongSide = max(contentSize.width, contentSize.height)
            guard contentLongSide.isFinite, contentLongSide > 0 else { return 1...1 }
            let minimumRatio = metric == .logo ? logoMinimumExtentRatio : routeMinimumExtentRatio
            return (coverShortSide * minimumRatio / contentLongSide)...(coverShortSide * maximumExtentRatio / contentLongSide)
        }
    }

    func defaultScale(for metric: VideoWatermarkMetric, contentSize: CGSize, maximumContentSize: CGSize) -> CGFloat {
        let range = range(for: metric, contentSize: contentSize, maximumContentSize: maximumContentSize)
        switch metric {
        case .speed, .altitude, .heartRate:
            let coverShortSide = min(coverCanvasSize.width, coverCanvasSize.height)
            let preferred = coverShortSide * defaultMetricFontRatio / baseMetricFontSize
            return min(max(preferred, range.lowerBound), range.upperBound)
        case .route, .logo:
            return range.lowerBound + (range.upperBound - range.lowerBound) * defaultRangeProgress
        }
    }

    func clamped(_ scale: CGFloat, for metric: VideoWatermarkMetric, contentSize: CGSize, maximumContentSize: CGSize) -> CGFloat {
        let range = range(for: metric, contentSize: contentSize, maximumContentSize: maximumContentSize)
        return min(max(scale, range.lowerBound), range.upperBound)
    }

    func clamped(_ layout: VideoWatermarkLayout, for contentSize: CGSize) -> VideoWatermarkLayout {
        guard coverCanvasSize.width > 0, coverCanvasSize.height > 0,
              contentSize.width > 0, contentSize.height > 0 else { return layout }
        let halfWidth = min(contentSize.width * CGFloat(layout.scale) / 2, coverCanvasSize.width / 2)
        let halfHeight = min(contentSize.height * CGFloat(layout.scale) / 2, coverCanvasSize.height / 2)
        var result = layout
        result.x = Double(min(max(CGFloat(layout.x) * coverCanvasSize.width, halfWidth), coverCanvasSize.width - halfWidth) / coverCanvasSize.width)
        result.y = Double(min(max(CGFloat(layout.y) * coverCanvasSize.height, halfHeight), coverCanvasSize.height - halfHeight) / coverCanvasSize.height)
        return result
    }
}

private struct WatermarkLayoutPreview: View {
    let metrics: Set<VideoWatermarkMetric>
    @Binding var layouts: [VideoWatermarkMetric: VideoWatermarkLayout]
    @Binding var selectedMetric: VideoWatermarkMetric?
    let maximumContentSizes: [VideoWatermarkMetric: CGSize]
    let media: VideoWatermarkMediaInfo
    let workout: VideoWatermarkWorkoutSnapshot
    @State private var draggingMetric: VideoWatermarkMetric?

    var body: some View {
        GeometryReader { geometry in
            let visibleMetrics = draggingMetric.map { metrics.subtracting(Set([$0])) } ?? metrics
            let renderedImage = VideoWatermarkOverlayRenderer.previewImage(
                metrics: visibleMetrics,
                layouts: layouts,
                workoutPoints: workout.points,
                videoTime: media.effectiveVideoStart,
                mediaCreationTime: media.creationTime,
                size: geometry.size,
                designSize: CGSize(width: media.width, height: media.height)
            )
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { selectedMetric = nil }

                if let renderedImage {
                    Image(decorative: renderedImage, scale: 1, orientation: .up)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .allowsHitTesting(false)
                }

                ForEach(VideoWatermarkMetric.allCases) { metric in
                    if metrics.contains(metric), let layout = layouts[metric] {
                        WatermarkPreviewItem(
                            metric: metric,
                            layout: binding(for: metric),
                            canvasSize: geometry.size,
                            contentSize: displayContentSize(for: metric, in: geometry.size),
                            boundaryContentSize: displayMaximumContentSize(for: metric, in: geometry.size),
                            isSelected: selectedMetric == metric,
                            dragImageProvider: {
                                // 拖拽图层必须只包含当前水印。若从合成预览裁切，重叠区域会把
                                // 其他水印一起带走，造成拖动 A 时 B 跟随 A 的视觉错误。
                                VideoWatermarkOverlayRenderer.previewImage(
                                    metrics: Set([metric]),
                                    layouts: layouts,
                                    workoutPoints: workout.points,
                                    videoTime: media.effectiveVideoStart,
                                    mediaCreationTime: media.creationTime,
                                    size: geometry.size,
                                    designSize: CGSize(width: media.width, height: media.height)
                                )
                            },
                            onSelect: { selectedMetric = metric },
                            onDragStateChange: { isDragging in
                                draggingMetric = isDragging ? metric : nil
                            }
                        )
                        .position(x: CGFloat(layout.x) * geometry.size.width, y: CGFloat(layout.y) * geometry.size.height)
                    }
                }

                if let selectedMetric, metrics.contains(selectedMetric) {
                    WatermarkScaleSlider(
                        value: scaleBinding(for: selectedMetric),
                        range: scalePolicy.range(
                            for: selectedMetric,
                            contentSize: sourceContentSize(for: selectedMetric),
                            maximumContentSize: maximumSourceContentSize(for: selectedMetric)
                        )
                    )
                        .padding(.leading, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .allowsHitTesting(true)
    }

    private func binding(for metric: VideoWatermarkMetric) -> Binding<VideoWatermarkLayout> {
        Binding(get: { layouts[metric] ?? .speed }, set: { layouts[metric] = $0 })
    }

    private var scalePolicy: VideoWatermarkScalePolicy {
        VideoWatermarkScalePolicy(coverCanvasSize: CGSize(width: media.width, height: media.height))
    }

    /// 数字水印按当前视频时刻的真实文案测量，不预留固定空白；虚线框使用这个尺寸。
    /// 滑杆上限和拖拽边界改用有效视频内的最大尺寸，避免后续数值变长时越界。
    private func sourceContentSize(for metric: VideoWatermarkMetric) -> CGSize {
        VideoWatermarkOverlayRenderer.previewContentSize(
            for: metric,
            workoutPoints: workout.points,
            videoTime: media.effectiveVideoStart,
            mediaCreationTime: media.creationTime
        )
    }

    private func displayContentSize(for metric: VideoWatermarkMetric, in canvasSize: CGSize) -> CGSize {
        let sourceSize = sourceContentSize(for: metric)
        return displaySize(for: sourceSize, in: canvasSize)
    }

    private func maximumSourceContentSize(for metric: VideoWatermarkMetric) -> CGSize {
        maximumContentSizes[metric] ?? sourceContentSize(for: metric)
    }

    private func displayMaximumContentSize(for metric: VideoWatermarkMetric, in canvasSize: CGSize) -> CGSize {
        displaySize(for: maximumSourceContentSize(for: metric), in: canvasSize)
    }

    private func displaySize(for sourceSize: CGSize, in canvasSize: CGSize) -> CGSize {
        return CGSize(
            width: sourceSize.width * canvasSize.width / CGFloat(max(media.width, 1)),
            height: sourceSize.height * canvasSize.height / CGFloat(max(media.height, 1))
        )
    }

    private func scaleBinding(for metric: VideoWatermarkMetric) -> Binding<CGFloat> {
        Binding(
            get: { CGFloat(layouts[metric]?.scale ?? 1) },
            set: { newScale in
                guard var layout = layouts[metric] else { return }
                let contentSize = sourceContentSize(for: metric)
                let maximumContentSize = maximumSourceContentSize(for: metric)
                layout.scale = Double(scalePolicy.clamped(newScale, for: metric, contentSize: contentSize, maximumContentSize: maximumContentSize))
                layout = scalePolicy.clamped(layout, for: maximumContentSize)
                layouts[metric] = layout
            }
        )
    }
}

private struct WatermarkPreviewItem: View {
    let metric: VideoWatermarkMetric
    @Binding var layout: VideoWatermarkLayout
    let canvasSize: CGSize
    let contentSize: CGSize
    let boundaryContentSize: CGSize
    let isSelected: Bool
    let dragImageProvider: () -> CGImage?
    let onSelect: () -> Void
    let onDragStateChange: (Bool) -> Void
    @State private var dragStart: VideoWatermarkLayout?
    @State private var isDragging = false
    @State private var dragImage: CGImage?
    @GestureState private var dragTranslation: CGSize = .zero

    var body: some View {
        ZStack {
            if isDragging, let image = croppedDragImage {
                Image(decorative: image, scale: 1, orientation: .up)
                    .resizable()
                    .interpolation(.high)
            }
            Color.clear
        }
        .frame(width: visualSize.width, height: visualSize.height)
        .overlay(selectionOutline)
        .contentShape(Rectangle())
        .offset(dragTranslation)
        .gesture(
            DragGesture(minimumDistance: 1)
                .updating($dragTranslation) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    if let start = dragStart {
                        layout = clamped(
                            VideoWatermarkLayout(
                                x: start.x + Double(value.translation.width / max(canvasSize.width, 1)),
                                y: start.y + Double(value.translation.height / max(canvasSize.height, 1)),
                                scale: start.scale
                            )
                        )
                    }
                    dragStart = nil
                    isDragging = false
                    dragImage = nil
                    onDragStateChange(false)
                }
                .onChanged { _ in
                    if !isDragging {
                        dragStart = layout
                        dragImage = dragImageProvider()
                        isDragging = true
                        onSelect()
                        onDragStateChange(true)
                    }
                }
        )
        .onTapGesture { onSelect() }
        .accessibilityLabel(Text(LocalizedStringKey(metric.titleKey)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var croppedDragImage: CGImage? {
        guard let dragImage, canvasSize.width > 0, canvasSize.height > 0 else { return nil }
        let renderScaleX = CGFloat(dragImage.width) / canvasSize.width
        let renderScaleY = CGFloat(dragImage.height) / canvasSize.height
        let size = visualSize
        let rect = CGRect(
            x: CGFloat(layout.x) * canvasSize.width * renderScaleX - size.width * renderScaleX / 2,
            y: CGFloat(layout.y) * canvasSize.height * renderScaleY - size.height * renderScaleY / 2,
            width: size.width * renderScaleX,
            height: size.height * renderScaleY
        ).integral
        let imageBounds = CGRect(x: 0, y: 0, width: dragImage.width, height: dragImage.height)
        return dragImage.cropping(to: rect.intersection(imageBounds))
    }

    private func clamped(_ layout: VideoWatermarkLayout) -> VideoWatermarkLayout {
        let halfWidth = min(boundaryVisualSize.width / 2, canvasSize.width / 2)
        let halfHeight = min(boundaryVisualSize.height / 2, canvasSize.height / 2)
        var result = layout
        result.x = Double(min(max(CGFloat(layout.x) * canvasSize.width, halfWidth), canvasSize.width - halfWidth) / max(canvasSize.width, 1))
        result.y = Double(min(max(CGFloat(layout.y) * canvasSize.height, halfHeight), canvasSize.height - halfHeight) / max(canvasSize.height, 1))
        return result
    }

    private var visualSize: CGSize {
        CGSize(width: contentSize.width * CGFloat(layout.scale), height: contentSize.height * CGFloat(layout.scale))
    }

    private var boundaryVisualSize: CGSize {
        CGSize(width: boundaryContentSize.width * CGFloat(layout.scale), height: boundaryContentSize.height * CGFloat(layout.scale))
    }

    private var selectionOutline: some View {
        return RoundedRectangle(cornerRadius: 6)
            .stroke(Color.white.opacity(isSelected ? 0.9 : 0), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            .frame(width: visualSize.width, height: visualSize.height)
            .padding(-6)
    }
}

private struct WatermarkScaleSlider: View {
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.magnifyingglass")
            Slider(value: $value, in: range)
                .frame(width: 150)
                .rotationEffect(.degrees(-90))
                .frame(width: 30, height: 150)
                .tint(.orange)
            Image(systemName: "minus.magnifyingglass")
        }
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(.white)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Capsule().fill(.black.opacity(0.35)))
    }
}

enum VideoWatermarkValidationError: Error {
    case invalidFormat
    case invalidDuration
    case missingCreationDate
    case invalidEffectiveRange

    var localizedKey: String {
        switch self {
        case .invalidFormat: return "video_watermark.error.invalid_format"
        case .invalidDuration: return "video_watermark.error.invalid_duration"
        case .missingCreationDate: return "video_watermark.error.no_creation_date"
        case .invalidEffectiveRange: return "video_watermark.error.invalid_effective_range"
        }
    }
}

struct VideoWatermarkVideoInspection {
    let sourceExtension: String
    let codec: String
    let width: Int
    let height: Int
    let nominalFrameRate: Double
    let duration: TimeInterval
    let creationTime: TimeInterval
    let hasAudio: Bool
    let sourceByteCount: Int64
    let isHDR: Bool
}

private enum VideoWatermarkDurationLimit {
    static let minimumSourceDuration: TimeInterval = 30
    static let maximumSourceDuration: TimeInterval = 3_600
    static let minimumEffectiveDuration: TimeInterval = 30
    static let maximumEffectiveDuration: TimeInterval = 3_600
}

enum VideoWatermarkMediaAnalyzer {
    /// PhotoKit 已提供的拍摄时间、时长和像素尺寸足够进入编辑页；编码会在任务真正取得原片后复核。
    static func inspect(asset: PHAsset, reference: VideoWatermarkPhotoAssetReference) throws -> VideoWatermarkVideoInspection {
        let ext = reference.sourceExtension
        guard ext == "mov" || ext == "mp4" else { throw VideoWatermarkValidationError.invalidFormat }
        let duration = asset.duration
        guard duration.isFinite,
              duration >= VideoWatermarkDurationLimit.minimumSourceDuration,
              duration <= VideoWatermarkDurationLimit.maximumSourceDuration else {
            throw VideoWatermarkValidationError.invalidDuration
        }
        guard let creationDate = asset.creationDate else { throw VideoWatermarkValidationError.missingCreationDate }
        guard asset.pixelWidth > 0, asset.pixelHeight > 0 else { throw VideoWatermarkValidationError.invalidFormat }
        return VideoWatermarkVideoInspection(
            sourceExtension: ext,
            codec: "unknown",
            width: asset.pixelWidth,
            height: asset.pixelHeight,
            nominalFrameRate: 0,
            duration: duration,
            creationTime: creationDate.timeIntervalSince1970,
            hasAudio: false,
            sourceByteCount: 0,
            isHDR: false
        )
    }

    static func inspectInBackground(url: URL) async throws -> VideoWatermarkVideoInspection {
        try await inspect(url: url)
    }

    /// 只请求 PhotoKit 已可访问的 AVAsset 索引，不允许 iCloud 下载完整原片。
    static func inspectPhotoAssetInBackground(asset: PHAsset, reference: VideoWatermarkPhotoAssetReference) async -> VideoWatermarkVideoInspection? {
        let options = PHVideoRequestOptions()
        options.version = .original
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = false
        let avAsset: AVAsset? = await withCheckedContinuation { continuation in
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { asset, _, _ in
                continuation.resume(returning: asset)
            }
        }
        guard let avAsset else { return nil }
        do {
            return try await inspect(asset: avAsset, sourceExtension: reference.sourceExtension, sourceByteCount: 0)
        } catch {
            Logger.videoWatermark.warning_public("photo asset lightweight inspection unavailable: \(error.localizedDescription)")
            return nil
        }
    }

    static func makeMediaInfo(inspection: VideoWatermarkVideoInspection, workout: VideoWatermarkWorkoutSnapshot) throws -> VideoWatermarkMediaInfo {
        guard let workoutStart = workout.startTime, let workoutEnd = workout.endTime else { throw VideoWatermarkValidationError.invalidEffectiveRange }
        let effectiveStart = max(inspection.creationTime, workoutStart)
        let effectiveEnd = min(inspection.creationTime + inspection.duration, workoutEnd)
        let effectiveDuration = effectiveEnd - effectiveStart
        Logger.videoWatermark.notice_public("video alignment calculated: video=\(String(format: "%.3f", inspection.creationTime))...\(String(format: "%.3f", inspection.creationTime + inspection.duration)), workout=\(String(format: "%.3f", workoutStart))...\(String(format: "%.3f", workoutEnd)), effective=\(String(format: "%.3f", effectiveStart))...\(String(format: "%.3f", effectiveEnd))")
        guard effectiveDuration >= VideoWatermarkDurationLimit.minimumEffectiveDuration,
              effectiveDuration <= VideoWatermarkDurationLimit.maximumEffectiveDuration else {
            throw VideoWatermarkValidationError.invalidEffectiveRange
        }
        return VideoWatermarkMediaInfo(
            sourceFileName: "source.\(inspection.sourceExtension)", outputFileName: "output.\(inspection.sourceExtension)",
            container: inspection.sourceExtension, codec: inspection.codec, width: inspection.width, height: inspection.height,
            nominalFrameRate: inspection.nominalFrameRate, duration: inspection.duration, creationTime: inspection.creationTime,
            effectiveVideoStart: effectiveStart - inspection.creationTime, effectiveDuration: effectiveDuration,
            hasAudio: inspection.hasAudio, sourceByteCount: inspection.sourceByteCount, isHDR: inspection.isHDR
        )
    }

    static func makeCoverImageInBackground(url: URL, at time: TimeInterval) async -> UIImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let asset = AVURLAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 720, height: 1_280)
                do {
                    let image = try generator.copyCGImage(at: CMTime(seconds: max(time, 0), preferredTimescale: 600), actualTime: nil)
                    Logger.videoWatermark.debug_public("video cover generated at \(String(format: "%.2f", time))s")
                    continuation.resume(returning: UIImage(cgImage: image))
                } catch {
                    Logger.videoWatermark.warning_public("video cover generation failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// 使用 Photos 已缓存的海报帧，避免为了编辑预览解码或下载整段视频。
    static func makeCoverImageInBackground(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = false
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 720, height: 1_280),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    private static func inspect(url: URL) async throws -> VideoWatermarkVideoInspection {
        let ext = url.pathExtension.lowercased()
        guard ext == "mov" || ext == "mp4" else {
            Logger.videoWatermark.error_public("video inspection rejected extension: file=\(url.lastPathComponent), extension=\(ext)")
            throw VideoWatermarkValidationError.invalidFormat
        }
        return try await inspect(
            asset: AVURLAsset(url: url),
            sourceExtension: ext,
            sourceByteCount: (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        )
    }

    private static func inspect(asset: AVAsset, sourceExtension ext: String, sourceByteCount: Int64) async throws -> VideoWatermarkVideoInspection {
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = videoTracks.first else {
            let trackTypes = try await asset.load(.tracks).map { $0.mediaType.rawValue }.joined(separator: ",")
            Logger.videoWatermark.error_public("video inspection found no video track: tracks=\(trackTypes.isEmpty ? "none" : trackTypes)")
            throw VideoWatermarkValidationError.invalidFormat
        }
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite,
              duration >= VideoWatermarkDurationLimit.minimumSourceDuration,
              duration <= VideoWatermarkDurationLimit.maximumSourceDuration else {
            Logger.videoWatermark.error_public("video inspection rejected duration: duration=\(duration)")
            throw VideoWatermarkValidationError.invalidDuration
        }
        let codec = try await codecName(track)
        guard codec == "avc1" || codec == "hvc1" || codec == "hev1" else {
            Logger.videoWatermark.error_public("video inspection rejected codec: codec=\(codec.isEmpty ? "unknown" : codec)")
            throw VideoWatermarkValidationError.invalidFormat
        }
        let commonMetadata = try await asset.load(.commonMetadata)
        var creationDate: Date?
        for metadataItem in commonMetadata {
            if let date = try await metadataItem.load(.dateValue) {
                creationDate = date
                break
            }
        }
        guard let creationDate else {
            Logger.videoWatermark.error_public("video inspection found no creation metadata: commonMetadataCount=\(commonMetadata.count)")
            throw VideoWatermarkValidationError.missingCreationDate
        }
        let creationTime = creationDate.timeIntervalSince1970
        let oriented = try await orientedSize(track)
        let nominalFrameRate = try await track.load(.nominalFrameRate)
        let hasAudio = !(try await asset.loadTracks(withMediaType: .audio)).isEmpty
        let isHDR = try await track.load(.mediaCharacteristics).contains(.containsHDRVideo)
        Logger.videoWatermark.debug_public("video inspection: codec=\(codec), size=\(Int(oriented.width))x\(Int(oriented.height)), duration=\(String(format: "%.3f", duration)), creation=\(String(format: "%.3f", creationTime)), audio=\(hasAudio), hdr=\(isHDR)")
        return VideoWatermarkVideoInspection(
            sourceExtension: ext, codec: codec, width: Int(oriented.width.rounded()), height: Int(oriented.height.rounded()),
            nominalFrameRate: Double(nominalFrameRate), duration: duration, creationTime: creationTime,
            hasAudio: hasAudio,
            sourceByteCount: sourceByteCount,
            isHDR: isHDR
        )
    }

    private static func codecName(_ track: AVAssetTrack) async throws -> String {
        guard let format = try await track.load(.formatDescriptions).first else { return "" }
        let code = CMFormatDescriptionGetMediaSubType(format)
        let bytes: [UInt8] = [UInt8((code >> 24) & 0xff), UInt8((code >> 16) & 0xff), UInt8((code >> 8) & 0xff), UInt8(code & 0xff)]
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }

    private static func orientedSize(_ track: AVAssetTrack) async throws -> CGSize {
        let naturalSize = try await track.load(.naturalSize)
        let preferredTransform = try await track.load(.preferredTransform)
        let size = naturalSize.applying(preferredTransform)
        return CGSize(width: abs(size.width), height: abs(size.height))
    }
}
