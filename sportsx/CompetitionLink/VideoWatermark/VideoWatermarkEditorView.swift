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
import Combine

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
            Logger.videoWatermark.debug_public("video import fallback received PhotosPicker file representation: bytes=\(receivedByteCount), file=\(received.file.lastPathComponent)")
            try FileManager.default.copyItem(at: received.file, to: destination)
            let byteCount = (try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            Logger.videoWatermark.debug_public("video import fallback copied PhotosPicker file into app temporary storage: bytes=\(byteCount), elapsed=\(String(format: "%.2f", Date().timeIntervalSince(copyStartedAt)))s")
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
        Logger.videoWatermark.debug_public("video import requested: itemIdentifier=\(item.itemIdentifier ?? "nil"), photoAuthorization=\(videoWatermarkPhotoAuthorizationName(authorization))")
        if let identifier = item.itemIdentifier {
            let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
            if let asset = result.firstObject,
               let resource = PHAssetResource.assetResources(for: asset).first(where: { $0.type == .fullSizeVideo || $0.type == .video }) {
                let reference = VideoWatermarkPhotoAssetReference(
                    localIdentifier: asset.localIdentifier,
                    resourceTypeRawValue: resource.type.rawValue,
                    originalFilename: resource.originalFilename
                )
                Logger.videoWatermark.debug_public("photo import retained PhotoKit reference without materializing source: asset=\(asset.localIdentifier), file=\(resource.originalFilename)")
                return .photoAsset(asset: asset, reference: reference)
            }
            Logger.videoWatermark.warning_public("video import could not resolve the selected asset")
            Logger.videoWatermark.debug_public("video import could not resolve PhotosPicker identifier through PhotoKit: identifier=\(identifier), fetched=\(result.count)")
        }

        // 某些来源不会暴露 PHAsset 标识，保留 PhotosPicker 的标准导入作为兼容兜底。
        Logger.videoWatermark.debug_public("photo import falling back to PhotosPicker transferable: no resolvable PHAsset identifier")
        progress(.fetching, nil, false)
        let fetchingStartedAt = Date()
        guard let imported = try await item.loadTransferable(type: VideoWatermarkImportedVideo.self) else {
            throw VideoWatermarkValidationError.invalidFormat
        }
        let byteCount = (try? imported.url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        Logger.videoWatermark.debug_public("video import PhotosPicker transferable ready in \(String(format: "%.2f", Date().timeIntervalSince(fetchingStartedAt)))s, bytes=\(byteCount), file=\(imported.url.lastPathComponent)")
        progress(.fetching, 1, true)
        return .temporaryFile(imported.url)
    }
}

/// 编辑页只保留用于预览的轻量 AVAsset；任务本身仍按原有策略保存 PhotoKit 引用，避免提前复制原片。
@MainActor
private final class VideoWatermarkPreviewFrameProvider: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var isPreparing = false
    @Published private(set) var preparationProgress: Double?

    private let imageCache = NSCache<NSNumber, UIImage>()
    private var asset: AVAsset?
    private var photoRequestID: PHImageRequestID = PHInvalidImageRequestID
    private var preparationID = UUID()
    private var frameRequest: Task<Void, Never>?
    private var requestedTime: TimeInterval = 0
    private var duration: TimeInterval = 0

    init() {
        imageCache.countLimit = 12
    }

    deinit {
        frameRequest?.cancel()
        if photoRequestID != PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(photoRequestID)
        }
    }

    func prepare(url: URL, at time: TimeInterval, duration: TimeInterval) {
        reset()
        self.duration = duration
        asset = AVURLAsset(url: url)
        requestFrame(at: time)
    }

    /// 对 iCloud 视频允许一次受进度反馈的下载；完成前保持相册提供的海报图作为底图。
    func prepare(photoAsset: PHAsset, at time: TimeInterval, duration: TimeInterval) {
        reset()
        self.duration = duration
        requestedTime = time
        isPreparing = true
        let id = preparationID
        let options = PHVideoRequestOptions()
        options.version = .original
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.progressHandler = { [weak self] progress, _, _, _ in
            Task { @MainActor in
                guard let self, self.preparationID == id else { return }
                self.preparationProgress = min(max(progress, 0), 1)
            }
        }
        photoRequestID = PHImageManager.default().requestAVAsset(forVideo: photoAsset, options: options) { [weak self] avAsset, _, info in
            Task { @MainActor in
                guard let self, self.preparationID == id else { return }
                self.photoRequestID = PHInvalidImageRequestID
                self.isPreparing = false
                self.preparationProgress = nil
                guard let avAsset else {
                    if let error = info?[PHImageErrorKey] as? Error {
                        Logger.videoWatermark.warning_public("video preview preparation failed")
                        Logger.videoWatermark.debug_public("video preview preparation failed: \(error.localizedDescription)")
                    }
                    return
                }
                self.asset = avAsset
                self.requestFrame(at: self.requestedTime)
            }
        }
    }

    func requestFrame(at time: TimeInterval) {
        let maximumTime = duration > 0 ? max(duration - 1.0 / 600.0, 0) : max(time, 0)
        requestedTime = min(max(time, 0), maximumTime)
        let cacheKey = NSNumber(value: Int((requestedTime * 10).rounded()))
        if let cached = imageCache.object(forKey: cacheKey) {
            image = cached
            return
        }
        guard let asset else { return }
        frameRequest?.cancel()
        let requestTime = requestedTime
        frameRequest = Task { [weak self] in
            // 进度线每个像素都会回调；短暂合并连续事件，避免 HEVC/4K 解码堆积。
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled,
                  let frame = await Self.makeFrame(from: asset, at: requestTime),
                  !Task.isCancelled,
                  let self else { return }
            let currentKey = NSNumber(value: Int((self.requestedTime * 10).rounded()))
            guard currentKey == cacheKey else { return }
            self.imageCache.setObject(frame, forKey: cacheKey)
            self.image = frame
        }
    }

    func cancel() {
        reset()
    }

    private func reset() {
        preparationID = UUID()
        frameRequest?.cancel()
        frameRequest = nil
        if photoRequestID != PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(photoRequestID)
        }
        photoRequestID = PHInvalidImageRequestID
        asset = nil
        duration = 0
        image = nil
        isPreparing = false
        preparationProgress = nil
        imageCache.removeAllObjects()
    }

    private nonisolated static func makeFrame(from asset: AVAsset, at time: TimeInterval) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 640)
        let tolerance = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance
        do {
            let result = try await generator.image(at: CMTime(seconds: max(time, 0), preferredTimescale: 600))
            return UIImage(cgImage: result.image)
        } catch {
            return nil
        }
    }
}

struct VideoWatermarkEditorView: View {
    let workout: VideoWatermarkWorkoutSnapshot
    let paceSnapshotPath: String?
    @ObservedObject private var taskManager = VideoWatermarkTaskManager.shared
    @ObservedObject private var navigationManager = NavigationManager.shared
    @ObservedObject private var userManager = UserManager.shared
    @StateObject private var previewFrameProvider = VideoWatermarkPreviewFrameProvider()

    @State private var selectedItem: PhotosPickerItem?
    @State private var showVideoPicker = false
    @State private var isRequestingPhotoLibraryAccess = false
    @State private var importedURL: URL?
    @State private var photoAssetReference: VideoWatermarkPhotoAssetReference?
    @State private var media: VideoWatermarkMediaInfo?
    @State private var overlayRange: VideoWatermarkOverlayRange?
    @State private var previewVideoTime: TimeInterval = 0
    @State private var isAutomaticAlignment = false
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
    @State private var paceSnapshot: VideoWatermarkPaceSnapshot?
    @State private var isLoadingPaceSnapshot = false

    // 导入完成前不会展示编辑画布，这组值只用于保持 State 的初始状态完整。
    // 真实初始尺寸会在拿到视频封面画布尺寸后重新计算。
    private static let placeholderLayouts: [VideoWatermarkMetric: VideoWatermarkLayout] = [
        .route: .route, .speed: .speed, .altitude: .altitude, .heartRate: .heartRate,
        .predictedRank: VideoWatermarkLayout(x: 0.5, y: 0.57, scale: 1),
        .pbTime: VideoWatermarkLayout(x: 0.5, y: 0.47, scale: 1),
        .pbDistance: VideoWatermarkLayout(x: 0.5, y: 0.37, scale: 1),
        .logo: .logo
    ]

    private static func maximumContentSizes(for media: VideoWatermarkMediaInfo, overlayRange: VideoWatermarkOverlayRange, workout: VideoWatermarkWorkoutSnapshot, paceTimeline: [VideoWatermarkPaceFrame]) -> [VideoWatermarkMetric: CGSize] {
        Dictionary(uniqueKeysWithValues: VideoWatermarkMetric.allCases.map { metric in
            (
                metric,
                VideoWatermarkOverlayRenderer.maximumPreviewContentSize(
                    for: metric,
                    workoutPoints: workout.points,
                    paceTimeline: paceTimeline,
                    workoutStart: overlayRange.workoutStart,
                    duration: overlayRange.duration
                )
            )
        })
    }

    private static func defaultLayouts(for media: VideoWatermarkMediaInfo, overlayRange: VideoWatermarkOverlayRange, workout: VideoWatermarkWorkoutSnapshot, paceTimeline: [VideoWatermarkPaceFrame], maximumContentSizes: [VideoWatermarkMetric: CGSize]) -> [VideoWatermarkMetric: VideoWatermarkLayout] {
        let policy = VideoWatermarkScalePolicy(coverCanvasSize: CGSize(width: media.width, height: media.height))
        return Dictionary(uniqueKeysWithValues: VideoWatermarkMetric.allCases.map { metric in
            var layout = baseLayout(for: metric)
            let contentSize = VideoWatermarkOverlayRenderer.previewContentSize(
                for: metric,
                workoutPoints: workout.points,
                paceTimeline: paceTimeline,
                workoutTime: overlayRange.workoutStart
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
        case .predictedRank: return VideoWatermarkLayout(x: 0.5, y: 0.57, scale: 1)
        case .pbTime: return VideoWatermarkLayout(x: 0.5, y: 0.47, scale: 1)
        case .pbDistance: return VideoWatermarkLayout(x: 0.5, y: 0.37, scale: 1)
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
                    if let media, let overlayRange {
                        preview(image: previewFrameProvider.image ?? previewImage, media: media, overlayRange: overlayRange)
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
        .photosPicker(isPresented: $showVideoPicker, selection: $selectedItem, matching: .videos, photoLibrary: .shared())
        .onValueChange(of: selectedItem) { _, item in
            guard let item else { return }
            importVideo(item)
        }
        .onValueChange(of: previewVideoTime) { _, time in
            previewFrameProvider.requestFrame(at: time)
        }
        .onAppear {
            if !workout.hasHeartRate { selectedMetrics.remove(.heartRate) }
            loadPaceSnapshot()
        }
        .onDisappear {
            previewFrameProvider.cancel()
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
    }

    private func preview(image: UIImage?, media: VideoWatermarkMediaInfo, overlayRange: VideoWatermarkOverlayRange) -> some View {
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
                        workout: workout,
                        overlayRange: overlayRange,
                        previewVideoTime: previewVideoTime,
                        paceTimeline: VideoWatermarkPaceTimelineBuilder.make(snapshot: paceSnapshot, workout: workout)
                    )
                    .frame(width: previewSize.width, height: previewSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack {
                        HStack {
                            Spacer()
                            Button(action: requestPhotoLibraryAccessAndPresentPicker) {
                                Label("video_watermark.action.reselect", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(.black.opacity(0.55), in: Capsule())
                            }
                            .disabled(isImporting || isRequestingPhotoLibraryAccess)
                            Spacer()
                        }
                        Spacer()
                        if previewFrameProvider.isPreparing {
                            VStack(spacing: 5) {
                                Text("video_watermark.preview.preparing")
                                    .font(.caption.weight(.semibold))
                                if let progress = previewFrameProvider.preparationProgress {
                                    ProgressView(value: progress)
                                        .tint(Color.orange)
                                    Text("\(Int((progress * 100).rounded()))%")
                                        .font(.caption2.monospacedDigit())
                                } else {
                                    ProgressView()
                                        .tint(Color.orange)
                                }
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 9))
                            .padding(.bottom, 8)
                        }
                    }
                    .padding(10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: previewHeight)
            .frame(maxWidth: .infinity)

            VideoWatermarkTimelineEditor(
                media: media,
                workout: workout,
                overlayRange: Binding(
                    get: { self.overlayRange ?? overlayRange },
                    set: { newValue in
                        self.overlayRange = newValue
                        self.previewVideoTime = min(max(self.previewVideoTime, 0), media.duration)
                    }
                ),
                previewVideoTime: $previewVideoTime,
                isAutomaticAlignment: isAutomaticAlignment
            )
            .frame(maxWidth: .infinity)
        }
    }

    private var metricPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("video_watermark.metric.title")
                .font(.headline)
                .foregroundStyle(Color.secondText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(VideoWatermarkMetric.allCases) { metric in
                        let unavailable = !isMetricAvailable(metric)
                        let islocked = (metric == .logo || metric.isPaceMetric) && !userManager.user.isVip
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
            Text("video_watermark.format.output_duration \(TimeDisplay.formattedTime(media.duration))")
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
                Logger.videoWatermark.debug_public("video import requesting Photos read-write authorization")
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
                // 允许用户再次选择同一个相册资源；取消选择时不影响当前已完成的编辑状态。
                selectedItem = nil
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
                let previewPhotoAsset: PHAsset?
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
                    previewPhotoAsset = asset
                case let .temporaryFile(url):
                    temporaryURL = url
                    inspection = try await VideoWatermarkMediaAnalyzer.inspectInBackground(url: url)
                    coverImage = await VideoWatermarkMediaAnalyzer.makeCoverImageInBackground(url: url, at: 0)
                    localURL = url
                    reference = nil
                    previewPhotoAsset = nil
                }
                updateImportProgress(stage: .aligning, progress: 0.94, isDeterminate: true)
                let info = VideoWatermarkMediaAnalyzer.makeMediaInfo(inspection: inspection)
                guard let initialAlignment = VideoWatermarkMediaAnalyzer.makeInitialOverlayRange(media: info, workout: workout) else {
                    throw VideoWatermarkValidationError.invalidFormat
                }
                await MainActor.run {
                    let previousImportedURL = importedURL
                    importedURL = localURL
                    photoAssetReference = reference
                    media = info
                    overlayRange = initialAlignment.range
                    previewVideoTime = initialAlignment.range.videoStart
                    isAutomaticAlignment = initialAlignment.isAutomatic
                    previewImage = coverImage
                    let paceTimeline = VideoWatermarkPaceTimelineBuilder.make(snapshot: paceSnapshot, workout: workout)
                    let maximumContentSizes = Self.maximumContentSizes(for: info, overlayRange: initialAlignment.range, workout: workout, paceTimeline: paceTimeline)
                    self.maximumContentSizes = maximumContentSizes
                    layouts = Self.defaultLayouts(for: info, overlayRange: initialAlignment.range, workout: workout, paceTimeline: paceTimeline, maximumContentSizes: maximumContentSizes)
                    outputFormat = Self.defaultOutputFormat(for: info)
                    selectedMetric = nil
                    isImporting = false
                    importProgress = 1
                    if let previousImportedURL, previousImportedURL != localURL {
                        try? FileManager.default.removeItem(at: previousImportedURL)
                    }
                    if let previewPhotoAsset {
                        previewFrameProvider.prepare(photoAsset: previewPhotoAsset, at: initialAlignment.range.videoStart, duration: info.duration)
                    } else if let localURL {
                        previewFrameProvider.prepare(url: localURL, at: initialAlignment.range.videoStart, duration: info.duration)
                    }
                    Logger.videoWatermark.debug_public("video import complete in \(String(format: "%.2f", Date().timeIntervalSince(startedAt)))s: \(info.codec) \(info.width)x\(info.height), duration=\(String(format: "%.2f", info.duration))s, overlayVideo=\(String(format: "%.2f", initialAlignment.range.videoStart))...\(String(format: "%.2f", initialAlignment.range.videoEnd))s, automatic=\(initialAlignment.isAutomatic), cover=\(coverImage == nil ? "unavailable" : "ready")")
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
                    Logger.videoWatermark.error_public("video import failed")
                    Logger.videoWatermark.debug_public("video import failed: \(error.localizedDescription)")
                    ToastManager.shared.show(toast: Toast(message: "video_watermark.error.import_failed"))
                }
            }
        }
    }

    @MainActor
    private func updateImportProgress(stage: VideoWatermarkImportStage, progress: Double?, isDeterminate: Bool) {
        if stage != importStage {
            Logger.videoWatermark.debug_public("video import stage: \(stage.logName)")
            importStage = stage
        }
        importProgress = isDeterminate ? progress.map { min(max($0, 0), 1) } : nil
    }

    private func createTask() {
        guard let media, let overlayRange, !selectedMetrics.isEmpty else { return }
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
        let paceTimeline = VideoWatermarkPaceTimelineBuilder.make(snapshot: paceSnapshot, workout: workout)
        let task = VideoWatermarkTask(userID: userID, workout: workout, paceSnapshot: paceSnapshot, paceTimeline: paceTimeline, media: media, overlayRange: overlayRange, photoAssetReference: photoAssetReference, outputFormat: outputFormat, selectedMetrics: selectedMetrics, layouts: layouts)
        // 后台导出会自行取得原片；停止编辑态预览下载，避免两个 PhotoKit 请求竞争网络和磁盘。
        previewFrameProvider.cancel()
        isCreatingTask = true
        Task {
            do {
                try await taskManager.createTask(task, importedSourceURL: importedURL)
                if let importedURL { try? FileManager.default.removeItem(at: importedURL) }
                ToastManager.shared.show(toast: Toast(message: "video_watermark.toast.queued"))
                PopupWindowManager.shared.presentPopup(
                    title: "video_watermark.task_created.title",
                    message: "video_watermark.task_created.message",
                    doNotShowAgainKey: "video_watermark.task_created",
                    bottomButtons: [.confirm()]
                )
                navigationManager.removeLast()
            } catch {
                Logger.videoWatermark.error_public("video watermark task creation failed")
                Logger.videoWatermark.debug_public("create task failed: \(error.localizedDescription)")
                ToastManager.shared.show(toast: Toast(message: "video_watermark.error.create_failed"))
                isCreatingTask = false
            }
        }
    }

    private func loadPaceSnapshot() {
        guard let paceSnapshotPath, !isLoadingPaceSnapshot else { return }
        isLoadingPaceSnapshot = true
        guard var components = URLComponents(string: paceSnapshotPath) else { return }
        components.queryItems = [URLQueryItem(name: "record_id", value: workout.recordID)]
        guard let path = components.url?.absoluteString else { return }
        let request = APIRequest(path: path, method: .get, requiresAuth: true)
        NetworkService.sendRequest(with: request, decodingType: VideoWatermarkPaceSnapshot.self, showErrorToast: false) { result in
            DispatchQueue.main.async {
                self.isLoadingPaceSnapshot = false
                if case .success(let snapshot) = result {
                    self.paceSnapshot = snapshot
                    if let media = self.media, let overlayRange = self.overlayRange {
                        let paceTimeline = VideoWatermarkPaceTimelineBuilder.make(snapshot: snapshot, workout: self.workout)
                        self.maximumContentSizes = Self.maximumContentSizes(for: media, overlayRange: overlayRange, workout: self.workout, paceTimeline: paceTimeline)
                    }
                    // PB 基线不存在时，PB 水印不能进入任务；排行榜为空不影响预测排名。
                    if snapshot?.pb_profile == nil {
                        self.selectedMetrics.remove(.pbTime)
                        self.selectedMetrics.remove(.pbDistance)
                        if self.selectedMetric == .pbTime || self.selectedMetric == .pbDistance {
                            self.selectedMetric = nil
                        }
                    }
                }
            }
        }
    }

    private func isMetricAvailable(_ metric: VideoWatermarkMetric) -> Bool {
        switch metric {
        case .heartRate:
            return workout.hasHeartRate
        case .predictedRank:
            // 即使赛前榜单为空，当前记录本身仍可形成 #1 / 1 的预测排名。
            return paceSnapshot != nil
        case .pbTime, .pbDistance:
            // PB 时间差/距离差必须有个人 PB 分段基线；空排行榜与此无关。
            return paceSnapshot?.pb_profile != nil
        case .route, .speed, .altitude, .logo:
            return true
        }
    }
}

#if DEBUG
private struct VideoWatermarkEditorPreviewConfiguration {
    let workout: VideoWatermarkWorkoutSnapshot
    let media: VideoWatermarkMediaInfo
    let overlayRange: VideoWatermarkOverlayRange
    let paceSnapshot: VideoWatermarkPaceSnapshot
    let previewImage: UIImage?
}

private extension VideoWatermarkEditorView {
    /// 仅供 SwiftUI Preview 直接进入完整编辑态，避免依赖相册与网络。
    init(preview configuration: VideoWatermarkEditorPreviewConfiguration) {
        self.workout = configuration.workout
        self.paceSnapshotPath = nil

        let paceTimeline = VideoWatermarkPaceTimelineBuilder.make(
            snapshot: configuration.paceSnapshot,
            workout: configuration.workout
        )
        let maximumContentSizes = Self.maximumContentSizes(
            for: configuration.media,
            overlayRange: configuration.overlayRange,
            workout: configuration.workout,
            paceTimeline: paceTimeline
        )
        let layouts = Self.defaultLayouts(
            for: configuration.media,
            overlayRange: configuration.overlayRange,
            workout: configuration.workout,
            paceTimeline: paceTimeline,
            maximumContentSizes: maximumContentSizes
        )

        _media = State(initialValue: configuration.media)
        _overlayRange = State(initialValue: configuration.overlayRange)
        _previewVideoTime = State(initialValue: configuration.overlayRange.videoStart + configuration.overlayRange.duration * 0.45)
        _previewImage = State(initialValue: configuration.previewImage)
        _outputFormat = State(initialValue: Self.defaultOutputFormat(for: configuration.media))
        _selectedMetrics = State(initialValue: Set(VideoWatermarkMetric.allCases))
        _layouts = State(initialValue: layouts)
        _maximumContentSizes = State(initialValue: maximumContentSizes)
        _paceSnapshot = State(initialValue: configuration.paceSnapshot)
    }
}
#endif

/// 最小的单片段时间轴：上轨调整水印数据与视频的对应关系，下轨始终代表完整原视频。
private struct VideoWatermarkTimelineEditor: View {
    let media: VideoWatermarkMediaInfo
    let workout: VideoWatermarkWorkoutSnapshot
    @Binding var overlayRange: VideoWatermarkOverlayRange
    @Binding var previewVideoTime: TimeInterval
    let isAutomaticAlignment: Bool

    private let handleWidth: CGFloat = 18
    @State private var moveStartRange: VideoWatermarkOverlayRange?
    @State private var leftTrimStartRange: VideoWatermarkOverlayRange?
    @State private var rightTrimStartRange: VideoWatermarkOverlayRange?
    @State private var isLeftHandleAtBoundary = false
    @State private var isRightHandleAtBoundary = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: isAutomaticAlignment ? "wand.and.stars" : "hand.draw")
                    .foregroundStyle(Color.orange)
                Text(isAutomaticAlignment ? "video_watermark.alignment.auto" : "video_watermark.alignment.manual")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondText)
            }

            GeometryReader { proxy in
                let width = max(proxy.size.width, 1)
                let startX = x(for: overlayRange.videoStart, width: width)
                let endX = x(for: overlayRange.videoEnd, width: width)
                ZStack(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 7) {
                        trackLabel("video_watermark.timeline.watermark")
                        
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.orange.opacity(0.28))
                                .frame(height: 24)

                            // 数据条和两个把手都在同一个时间轴坐标系中定位，避免 offset/overlay
                            // 的修饰器顺序造成把手看起来脱离数据条
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.orange)
                                    .frame(width: max(endX - startX, 10), height: 24)
                                    .offset(x: startX)
                                    .gesture(moveGesture(width: width))
                                Image(systemName: "line.3.horizontal")
                                    .rotationEffect(.degrees(90))
                                    .foregroundStyle(Color.secondText)
                                    .font(.system(size: 18, weight: .medium))
                                    .frame(width: 20)
                                    .offset(x: startX + (max(endX - startX, 10) / 2) - 10)
                            }
                            // 左把手
                            ZStack {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(isLeftHandleAtBoundary ? Color.red : .white.opacity(0.92))
                                    .frame(width: 3, height: 14)
                            }
                            .frame(width: handleWidth, height: 24)
                            .contentShape(Rectangle())
                            .position(x: startX, y: 12)
                            .highPriorityGesture(leftTrimGesture(width: width))
                            // 右把手
                            ZStack {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(isRightHandleAtBoundary ? Color.red : .white.opacity(0.92))
                                    .frame(width: 3, height: 14)
                            }
                            .frame(width: handleWidth, height: 24)
                            .contentShape(Rectangle())
                            .position(x: endX, y: 12)
                            .highPriorityGesture(rightTrimGesture(width: width))
                        }
                        .frame(height: 24)
                        
                        HStack {
                            trackLabel("video_watermark.timeline.original")
                            Spacer()
                            Text("\(TimeDisplay.formattedTime(overlayRange.videoStart)) – \(TimeDisplay.formattedTime(overlayRange.videoEnd)) · \(TimeDisplay.formattedTime(overlayRange.duration))")
                                .monospacedDigit()
                                .font(.caption2)
                                .foregroundStyle(Color.secondText)
                        }
                        
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                            .frame(height: 24)
                            .contentShape(Rectangle())
                            .gesture(previewGesture(width: width))
                    }
                    // 预览进度线
                    Rectangle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 1.5, height: 71)
                        .offset(x: x(for: previewVideoTime, width: width) - 0.75, y: 15)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 100)

            HStack {
                Text(TimeDisplay.formattedTime(0)).monospacedDigit()
                Spacer()
                Text(TimeDisplay.formattedTime(media.duration)).monospacedDigit()
            }
            .font(.caption2)
            .foregroundStyle(Color.thirdText)
        }
        .padding(10)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
        .onAppear(perform: refreshHandleBoundaryStates)
    }

    private func trackLabel(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.85))
    }

    private func x(for time: TimeInterval, width: CGFloat) -> CGFloat {
        width * min(max(time / max(media.duration, 0.001), 0), 1)
    }

    private func seconds(for translation: CGFloat, width: CGFloat) -> TimeInterval {
        TimeInterval(translation / max(width, 1)) * media.duration
    }

    /// 片段在时间轴上至少保留 10pt，避免两个把手重合导致命中区域相互抢手势。
    private func minimumDuration(for width: CGFloat) -> TimeInterval {
        let availableDuration = min(media.duration, max((workout.endTime ?? 0) - (workout.startTime ?? 0), 0))
        let tenPointDuration = TimeInterval(10 / max(width, 1)) * media.duration
        return min(max(tenPointDuration, 0.001), availableDuration)
    }

    private func moveGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if moveStartRange == nil { moveStartRange = overlayRange }
                guard let startRange = moveStartRange else { return }
                let delta = seconds(for: value.translation.width, width: width)
                let maximumStart = max(media.duration - startRange.duration, 0)
                overlayRange.videoStart = min(max(startRange.videoStart + delta, 0), maximumStart)
            }
            .onEnded { _ in
                previewVideoTime = min(max(overlayRange.videoStart + overlayRange.duration / 2, 0), media.duration)
                moveStartRange = nil
            }
    }

    private func leftTrimGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if leftTrimStartRange == nil { leftTrimStartRange = overlayRange }
                guard let startRange = leftTrimStartRange else { return }
                let delta = seconds(for: value.translation.width, width: width)
                let workoutStart = workout.startTime ?? overlayRange.workoutStart
                let lowerBound = max(-startRange.videoStart, workoutStart - startRange.workoutStart)
                let upperBound = startRange.duration - minimumDuration(for: width)
                let applied = min(max(delta, lowerBound), upperBound)
                overlayRange.videoStart = startRange.videoStart + applied
                overlayRange.workoutStart = startRange.workoutStart + applied
                overlayRange.duration = startRange.duration - applied
                notifyLeftBoundaryIfNeeded(isLeftHandleAtWorkoutBoundary)
            }
            .onEnded { _ in
                previewVideoTime = overlayRange.videoStart
                leftTrimStartRange = nil
            }
    }

    private func rightTrimGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if rightTrimStartRange == nil { rightTrimStartRange = overlayRange }
                guard let startRange = rightTrimStartRange else { return }
                let delta = seconds(for: value.translation.width, width: width)
                let workoutEnd = workout.endTime ?? startRange.workoutEnd
                let maximumDuration = min(media.duration - startRange.videoStart, workoutEnd - startRange.workoutStart)
                let newDuration = min(max(startRange.duration + delta, minimumDuration(for: width)), maximumDuration)
                overlayRange.duration = newDuration
                notifyRightBoundaryIfNeeded(isRightHandleAtWorkoutBoundary)
            }
            .onEnded { _ in
                previewVideoTime = overlayRange.videoEnd
                rightTrimStartRange = nil
            }
    }

    private func previewGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                previewVideoTime = min(max(TimeInterval(value.location.x / max(width, 1)) * media.duration, 0), media.duration)
            }
    }

    private func notifyLeftBoundaryIfNeeded(_ isAtBoundary: Bool) {
        if isAtBoundary, !isLeftHandleAtBoundary {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        isLeftHandleAtBoundary = isAtBoundary
    }

    private func notifyRightBoundaryIfNeeded(_ isAtBoundary: Bool) {
        if isAtBoundary, !isRightHandleAtBoundary {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        isRightHandleAtBoundary = isAtBoundary
    }

    /// 红色和触感代表“这一侧没有更多运动数据”，而非视频刚好到头。
    private var isLeftHandleAtWorkoutBoundary: Bool {
        guard let workoutStart = workout.startTime else { return false }
        return overlayRange.workoutStart <= workoutStart + 0.001
    }

    private var isRightHandleAtWorkoutBoundary: Bool {
        guard let workoutEnd = workout.endTime else { return false }
        return overlayRange.workoutEnd >= workoutEnd - 0.001
    }

    private func refreshHandleBoundaryStates() {
        isLeftHandleAtBoundary = isLeftHandleAtWorkoutBoundary
        isRightHandleAtBoundary = isRightHandleAtWorkoutBoundary
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
        case .speed, .altitude, .heartRate, .predictedRank, .pbTime, .pbDistance:
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
        case .speed, .altitude, .heartRate, .predictedRank, .pbTime, .pbDistance:
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
    let overlayRange: VideoWatermarkOverlayRange
    let previewVideoTime: TimeInterval
    let paceTimeline: [VideoWatermarkPaceFrame]
    @State private var draggingMetric: VideoWatermarkMetric?

    var body: some View {
        GeometryReader { geometry in
            let visibleMetrics = draggingMetric.map { metrics.subtracting(Set([$0])) } ?? metrics
            let workoutTime = overlayRange.workoutTime(for: previewVideoTime)
            let renderedImage = workoutTime.flatMap {
                VideoWatermarkOverlayRenderer.previewImage(
                    metrics: visibleMetrics,
                    layouts: layouts,
                    workoutPoints: workout.points,
                    paceTimeline: paceTimeline,
                    workoutTime: $0,
                    size: geometry.size,
                    designSize: CGSize(width: media.width, height: media.height)
                )
            }
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

                if let workoutTime {
                    ForEach(VideoWatermarkMetric.allCases) { metric in
                        if metrics.contains(metric), let layout = layouts[metric] {
                            WatermarkPreviewItem(
                                metric: metric,
                                layout: binding(for: metric),
                                canvasSize: geometry.size,
                                contentSize: displayContentSize(for: metric, in: geometry.size),
                                boundaryContentSize: displayMaximumContentSize(for: metric, in: geometry.size),
                                isSelected: selectedMetric == metric,
                                previewVideoTime: previewVideoTime,
                                dragImageProvider: {
                                    // 拖拽图层必须只包含当前水印。若从合成预览裁切，重叠区域会把
                                    // 其他水印一起带走，造成拖动 A 时 B 跟随 A 的视觉错误。
                                    VideoWatermarkOverlayRenderer.previewImage(
                                        metrics: Set([metric]),
                                        layouts: layouts,
                                        workoutPoints: workout.points,
                                        paceTimeline: paceTimeline,
                                        workoutTime: workoutTime,
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
        // 时间轴开始移动时，临时拖拽截图不能继续参与合成；否则它会冻结在旧时刻。
        .onValueChange(of: previewVideoTime) { _, _ in
            draggingMetric = nil
        }
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
            paceTimeline: paceTimeline,
            workoutTime: overlayRange.workoutTime(for: previewVideoTime) ?? overlayRange.workoutStart
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
    let previewVideoTime: TimeInterval
    let dragImageProvider: () -> CGImage?
    let onSelect: () -> Void
    let onDragStateChange: (Bool) -> Void
    @State private var dragStart: VideoWatermarkLayout?
    @State private var dragImage: CGImage?
    @GestureState private var dragTranslation: CGSize = .zero
    @GestureState private var isGestureActive = false

    var body: some View {
        ZStack {
            if isGestureActive, let image = croppedDragImage {
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
                .updating($isGestureActive) { _, state, _ in
                    state = true
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
                    clearTransientDragState()
                }
                .onChanged { _ in
                    if dragStart == nil {
                        dragStart = layout
                        dragImage = dragImageProvider()
                        onSelect()
                        onDragStateChange(true)
                    }
                }
        )
        // `@GestureState` 会在系统取消手势时自动复位；据此清理普通 State，不能只依赖 onEnded。
        .onValueChange(of: isGestureActive) { wasActive, isActive in
            if wasActive && !isActive {
                clearTransientDragState()
            }
        }
        // 时间轴与位置拖拽不能共享冻结截图。切换时间时立即回到实时合成层。
        .onValueChange(of: previewVideoTime) { _, _ in
            clearTransientDragState()
        }
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

    private func clearTransientDragState() {
        guard dragStart != nil || dragImage != nil else { return }
        dragStart = nil
        dragImage = nil
        onDragStateChange(false)
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

    var localizedKey: String {
        switch self {
        case .invalidFormat: return "video_watermark.error.invalid_format"
        case .invalidDuration: return "video_watermark.error.invalid_duration"
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
    let creationTime: TimeInterval?
    let hasAudio: Bool
    let sourceByteCount: Int64
    let isHDR: Bool
}

private enum VideoWatermarkDurationLimit {
    static let minimumSourceDuration: TimeInterval = 30
    static let maximumSourceDuration: TimeInterval = 3_600
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
        guard asset.pixelWidth > 0, asset.pixelHeight > 0 else { throw VideoWatermarkValidationError.invalidFormat }
        return VideoWatermarkVideoInspection(
            sourceExtension: ext,
            codec: "unknown",
            width: asset.pixelWidth,
            height: asset.pixelHeight,
            nominalFrameRate: 0,
            duration: duration,
            creationTime: asset.creationDate?.timeIntervalSince1970,
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
            Logger.videoWatermark.warning_public("photo asset inspection unavailable")
            Logger.videoWatermark.debug_public("photo asset lightweight inspection unavailable: \(error.localizedDescription)")
            return nil
        }
    }

    static func makeMediaInfo(inspection: VideoWatermarkVideoInspection) -> VideoWatermarkMediaInfo {
        return VideoWatermarkMediaInfo(
            sourceFileName: "source.\(inspection.sourceExtension)", outputFileName: "output.\(inspection.sourceExtension)",
            container: inspection.sourceExtension, codec: inspection.codec, width: inspection.width, height: inspection.height,
            nominalFrameRate: inspection.nominalFrameRate, duration: inspection.duration, creationTime: inspection.creationTime,
            hasAudio: inspection.hasAudio, sourceByteCount: inspection.sourceByteCount, isHDR: inspection.isHDR
        )
    }

    /// 将拍摄时间作为便利的初始值，而不是导入或导出的约束。没有可靠元数据时，从两个时间轴的起点开始。
    static func makeInitialOverlayRange(media: VideoWatermarkMediaInfo, workout: VideoWatermarkWorkoutSnapshot) -> (range: VideoWatermarkOverlayRange, isAutomatic: Bool)? {
        guard let workoutStart = workout.startTime, let workoutEnd = workout.endTime else { return nil }
        let workoutDuration = workoutEnd - workoutStart
        let fallbackDuration = min(max(media.duration, 0), max(workoutDuration, 0))
        guard fallbackDuration > 0 else { return nil }
        guard let creationTime = media.creationTime else {
            return (VideoWatermarkOverlayRange(videoStart: 0, workoutStart: workoutStart, duration: fallbackDuration), false)
        }
        let alignedStart = max(creationTime, workoutStart)
        let alignedEnd = min(creationTime + media.duration, workoutEnd)
        let alignedDuration = alignedEnd - alignedStart
        guard alignedDuration > 0 else {
            Logger.videoWatermark.debug_public("video automatic alignment has no overlap; using timeline starts")
            return (VideoWatermarkOverlayRange(videoStart: 0, workoutStart: workoutStart, duration: fallbackDuration), false)
        }
        Logger.videoWatermark.debug_public("video automatic alignment calculated: video=\(String(format: "%.3f", creationTime))...\(String(format: "%.3f", creationTime + media.duration)), workout=\(String(format: "%.3f", workoutStart))...\(String(format: "%.3f", workoutEnd)), overlay=\(String(format: "%.3f", alignedStart))...\(String(format: "%.3f", alignedEnd))")
        return (VideoWatermarkOverlayRange(videoStart: alignedStart - creationTime, workoutStart: alignedStart, duration: alignedDuration), true)
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
                    Logger.videoWatermark.warning_public("video cover generation failed")
                    Logger.videoWatermark.debug_public("video cover generation failed: \(error.localizedDescription)")
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
            Logger.videoWatermark.error_public("video inspection rejected unsupported format")
            Logger.videoWatermark.debug_public("video inspection rejected extension: file=\(url.lastPathComponent), extension=\(ext)")
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
            Logger.videoWatermark.error_public("video inspection found no video track")
            Logger.videoWatermark.debug_public("video inspection found no video track: tracks=\(trackTypes.isEmpty ? "none" : trackTypes)")
            throw VideoWatermarkValidationError.invalidFormat
        }
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite,
              duration >= VideoWatermarkDurationLimit.minimumSourceDuration,
              duration <= VideoWatermarkDurationLimit.maximumSourceDuration else {
            Logger.videoWatermark.error_public("video inspection rejected duration")
            Logger.videoWatermark.debug_public("video inspection rejected duration: duration=\(duration)")
            throw VideoWatermarkValidationError.invalidDuration
        }
        let codec = try await codecName(track)
        guard codec == "avc1" || codec == "hvc1" || codec == "hev1" else {
            Logger.videoWatermark.error_public("video inspection rejected codec")
            Logger.videoWatermark.debug_public("video inspection rejected codec: codec=\(codec.isEmpty ? "unknown" : codec)")
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
        let creationTime = creationDate?.timeIntervalSince1970
        let oriented = try await orientedSize(track)
        let nominalFrameRate = try await track.load(.nominalFrameRate)
        let hasAudio = !(try await asset.loadTracks(withMediaType: .audio)).isEmpty
        let isHDR = try await track.load(.mediaCharacteristics).contains(.containsHDRVideo)
        Logger.videoWatermark.debug_public("video inspection: codec=\(codec), size=\(Int(oriented.width))x\(Int(oriented.height)), duration=\(String(format: "%.3f", duration)), creation=\(creationTime.map { String(format: "%.3f", $0) } ?? "missing"), audio=\(hasAudio), hdr=\(isHDR)")
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

#if DEBUG
#Preview("Video Watermark Editor") {
    let start: TimeInterval = 1_720_000_000
    let path = [
        PathPoint(lat: 31.2280, lon: 121.4730, speed: 4.6, altitude: 12, heart_rate: 136, timestamp: start),
        PathPoint(lat: 31.2288, lon: 121.4741, speed: 5.0, altitude: 15, heart_rate: 142, timestamp: start + 30),
        PathPoint(lat: 31.2300, lon: 121.4757, speed: 5.3, altitude: 19, heart_rate: 148, timestamp: start + 60),
        PathPoint(lat: 31.2312, lon: 121.4772, speed: 5.1, altitude: 17, heart_rate: 151, timestamp: start + 90),
        PathPoint(lat: 31.2323, lon: 121.4786, speed: 4.8, altitude: 14, heart_rate: 145, timestamp: start + 120)
    ]
    let workout = VideoWatermarkWorkoutSnapshot(
        recordID: "preview-watermark-workout",
        sport: .Running,
        kind: .routeTraining,
        basePath: path,
        pacePoints: path.map { VideoWatermarkPacePoint(timestamp: $0.timestamp, cumulativeCardBonus: 0) }
    )
    let media = VideoWatermarkMediaInfo(
        sourceFileName: "preview.mov",
        outputFileName: "preview-output.mov",
        container: "mov",
        codec: "hvc1",
        width: 1_920,
        height: 1_080,
        nominalFrameRate: 30,
        duration: 120,
        creationTime: start,
        hasAudio: true,
        sourceByteCount: 0,
        isHDR: false
    )
    let routeData: JSONValue = .object([
        "steps": .array([
            .object([
                "kind": .string("segment"),
                "width": .number(5),
                "points": .array(path.map { .array([.number($0.lat), .number($0.lon)]) })
            ])
        ])
    ])
    let paceSnapshot = VideoWatermarkPaceSnapshot(
        version: 1,
        finish_times: [420, 448, 472, 501, 540, 585, 630, 690, 750, 830, 920, 1_020],
        pb_profile: SplitProfile(L: 820, N: 4, splits: [-45, 118, 238, 362, 486]),
        route_data: routeData
    )
    let previewImage = UIGraphicsImageRenderer(size: CGSize(width: 1_920, height: 1_080)).image { context in
        UIColor(red: 0.08, green: 0.16, blue: 0.22, alpha: 1).setFill()
        context.fill(CGRect(x: 0, y: 0, width: 1_920, height: 1_080))
        let colors = [UIColor.systemTeal.cgColor, UIColor.systemIndigo.cgColor] as CFArray
        CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]).map {
            context.cgContext.drawLinearGradient(
                $0,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 1_920, y: 1_080),
                options: []
            )
        }
    }

    VideoWatermarkEditorView(preview: VideoWatermarkEditorPreviewConfiguration(
        workout: workout,
        media: media,
        overlayRange: VideoWatermarkOverlayRange(videoStart: 0, workoutStart: start, duration: 120),
        paceSnapshot: paceSnapshot,
        previewImage: previewImage
    ))
}
#endif
