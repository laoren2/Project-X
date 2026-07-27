//
//  VideoWatermarkExportEngine.swift
//  sportsx
//
//  使用 AVAssetReader / AVAssetWriter 在本地逐帧合成水印并重新编码视频。
//

import AVFoundation
import CoreImage
import VideoToolbox
import os

/// AVFoundation 的同步读写循环运行在 GCD 队列中，不会自动继承 Swift Task 的取消状态。
/// 通过这个令牌把 UI 的暂停/取消请求显式传入逐帧导出循环。
final class VideoWatermarkExportCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    func checkCancellation() throws {
        if isCancelled { throw CancellationError() }
    }
}

struct VideoWatermarkExportResult {
    let outputByteCount: Int64
}

private struct VideoWatermarkAudioAppendResult {
    let sampleCount: Int
    let firstPresentationTime: Double?
    let lastPresentationTime: Double?
    let wallElapsed: TimeInterval
}

/// 音频附加在独立队列运行；用锁保护其结果，以便视频收尾阶段能可靠地记录和读取状态。
private final class VideoWatermarkAudioAppendState: @unchecked Sendable {
    private let lock = NSLock()
    private var storedResult: VideoWatermarkAudioAppendResult?
    private var storedError: Error?

    func complete(with result: VideoWatermarkAudioAppendResult) {
        lock.lock()
        storedResult = result
        lock.unlock()
    }

    func fail(with error: Error) {
        lock.lock()
        storedError = error
        lock.unlock()
    }

    var result: VideoWatermarkAudioAppendResult? {
        lock.lock()
        defer { lock.unlock() }
        return storedResult
    }

    var error: Error? {
        lock.lock()
        defer { lock.unlock() }
        return storedError
    }
}

/// `requestMediaDataWhenReady` 的回调和取消路径都可能尝试结束同一条媒体管线。
/// 仅允许第一个调用者关闭 input 并离开 DispatchGroup，防止重复结束或永久等待。
private final class VideoWatermarkProducerState: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false
    private var storedError: Error?

    func finish(error: Error? = nil) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return false }
        finished = true
        storedError = error
        return true
    }

    var error: Error? {
        lock.lock()
        defer { lock.unlock() }
        return storedError
    }
}

private final class VideoWatermarkProducerActivity: @unchecked Sendable {
    struct Snapshot {
        let lastActivityAt: Date
        let videoFrameCount: Int
        let audioSampleCount: Int
    }

    private let lock = NSLock()
    private var lastActivityAt = Date()
    private var videoFrameCount = 0
    private var audioSampleCount = 0

    func recordVideoFrame() {
        lock.lock()
        videoFrameCount += 1
        lastActivityAt = Date()
        lock.unlock()
    }

    func recordAudioSample() {
        lock.lock()
        audioSampleCount += 1
        lastActivityAt = Date()
        lock.unlock()
    }

    var snapshot: Snapshot {
        lock.lock()
        defer { lock.unlock() }
        return Snapshot(lastActivityAt: lastActivityAt, videoFrameCount: videoFrameCount, audioSampleCount: audioSampleCount)
    }
}

private struct VideoWatermarkExportPreparation {
    let asset: AVURLAsset
    let videoTrack: AVAssetTrack
    let audioTrack: AVAssetTrack?
    let sourceSize: CGSize
    let preferredTransform: CGAffineTransform
    let nominalFrameRate: Double
    let isHDR: Bool
    let assetDuration: CMTime
}

enum VideoWatermarkExportError: LocalizedError {
    case missingVideoTrack
    case unableToRead
    case unableToWrite
    case unableToCreatePixelBuffer
    case appendFailed
    case noWatermarkRendered
    case unsupportedHDR
    case unableToRenderSDR

    var errorDescription: String? {
        switch self {
        case .missingVideoTrack: return "Missing video track"
        case .unableToRead: return "Unable to read video"
        case .unableToWrite: return "Unable to write video"
        case .unableToCreatePixelBuffer: return "Unable to create output pixel buffer"
        case .appendFailed: return "Unable to append video frame"
        case .noWatermarkRendered: return "No watermark frame was rendered"
        case .unsupportedHDR: return "HDR output was selected for a non-HDR source"
        case .unableToRenderSDR: return "Unable to create the SDR render color space"
        }
    }
}

enum VideoWatermarkExportEngine {
    static func export(task: VideoWatermarkTask, sourceURL: URL, outputURL: URL, cancellation: VideoWatermarkExportCancellation, onProgress: @escaping @Sendable (Double) -> Void) async throws -> VideoWatermarkExportResult {
        try await withTaskCancellationHandler(operation: {
            try cancellation.checkCancellation()
            let preparation = try await prepareExport(sourceURL: sourceURL)
            try cancellation.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                // 此 worker 主要等待 producer 回调；视频 producer 自身仍使用 userInitiated QoS。
                // 降低等待者优先级可避免它阻塞 Utility 音频 producer 造成 priority inversion。
                DispatchQueue.global(qos: .utility).async {
                    do {
                        try cancellation.checkCancellation()
                        let result = try exportSynchronously(task: task, sourceURL: sourceURL, outputURL: outputURL, preparation: preparation, cancellation: cancellation, onProgress: onProgress)
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }, onCancel: {
            cancellation.cancel()
        })
    }

    private static func prepareExport(sourceURL: URL) async throws -> VideoWatermarkExportPreparation {
        let asset = AVURLAsset(url: sourceURL)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoWatermarkExportError.missingVideoTrack
        }
        let audioTrack = try await asset.loadTracks(withMediaType: .audio).first
        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let sourceSize = orientedSize(naturalSize: naturalSize, preferredTransform: preferredTransform)
        let isHDR = try await videoTrack.load(.mediaCharacteristics).contains(.containsHDRVideo)
        return VideoWatermarkExportPreparation(
            asset: asset,
            videoTrack: videoTrack,
            audioTrack: audioTrack,
            sourceSize: sourceSize,
            preferredTransform: preferredTransform,
            nominalFrameRate: Double(try await videoTrack.load(.nominalFrameRate)),
            isHDR: isHDR,
            assetDuration: try await asset.load(.duration)
        )
    }

    private static func exportSynchronously(task: VideoWatermarkTask, sourceURL: URL, outputURL: URL, preparation: VideoWatermarkExportPreparation, cancellation: VideoWatermarkExportCancellation, onProgress: @escaping @Sendable (Double) -> Void) throws -> VideoWatermarkExportResult {
        try cancellation.checkCancellation()
        let asset = preparation.asset
        let videoTrack = preparation.videoTrack
        let audioTrack = preparation.audioTrack
        let sourceSize = preparation.sourceSize
        let outputFormat = task.outputFormat
        let outputSize = outputSize(sourceSize: sourceSize, format: outputFormat)
        let frameRate = Int32(outputFormat.frameRate.rawValue)
        let isHDROutput = outputFormat.dynamicRange == .hdr
        guard !isHDROutput || preparation.isHDR else {
            throw VideoWatermarkExportError.unsupportedHDR
        }
        let sourceFrameRate = task.media.nominalFrameRate > 0 ? task.media.nominalFrameRate : preparation.nominalFrameRate
        let timeRange = CMTimeRange(start: CMTime(seconds: task.media.effectiveVideoStart, preferredTimescale: 600), duration: CMTime(seconds: task.media.effectiveDuration, preferredTimescale: 600))
        let exportStartedAt = Date()
        Logger.videoWatermark.notice_public("watermark export prepared: task=\(task.id.uuidString), source=\(sourceURL.lastPathComponent), sourceSize=\(Int(sourceSize.width))x\(Int(sourceSize.height)), outputSize=\(Int(outputSize.width))x\(Int(outputSize.height)), sourceFrameRate=\(String(format: "%.0f", sourceFrameRate)), outputFrameRate=\(frameRate), timeRangeStart=\(String(format: "%.3f", task.media.effectiveVideoStart)), duration=\(String(format: "%.3f", task.media.effectiveDuration)), metrics=\(task.selectedMetrics.map(\.rawValue).sorted().joined(separator: ","))")

        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = timeRange
        let videoComposition = makeVideoComposition(track: videoTrack, preferredTransform: preparation.preferredTransform, sourceSize: sourceSize, renderSize: outputSize, frameRate: frameRate, duration: preparation.assetDuration, dynamicRange: outputFormat.dynamicRange)
        let pixelFormat = isHDROutput ? kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange : kCVPixelFormatType_32BGRA
        let sdrColorSpace = CGColorSpace(name: CGColorSpace.itur_709)
        Logger.videoWatermark.notice_public("watermark export color pipeline: task=\(task.id.uuidString), sourceHDR=\(preparation.isHDR), outputRange=\(outputFormat.dynamicRange.rawValue), readerPixelFormat=\(pixelFormat), targetColorSpace=\(isHDROutput ? "source HDR" : "Rec.709 SDR")")
        let videoOutput = AVAssetReaderVideoCompositionOutput(videoTracks: [videoTrack], videoSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormat
        ])
        videoOutput.videoComposition = videoComposition
        videoOutput.alwaysCopiesSampleData = false
        guard reader.canAdd(videoOutput) else { throw VideoWatermarkExportError.unableToRead }
        reader.add(videoOutput)

        let audioOutput: AVAssetReaderTrackOutput?
        if let audioTrack {
            let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM])
            output.alwaysCopiesSampleData = false
            guard reader.canAdd(output) else { throw VideoWatermarkExportError.unableToRead }
            reader.add(output)
            audioOutput = output
        } else {
            audioOutput = nil
        }

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: outputFileType(for: task))
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings(for: task, size: outputSize, frameRate: frameRate, outputFormat: outputFormat))
        videoInput.expectsMediaDataInRealTime = false
        guard writer.canAdd(videoInput) else { throw VideoWatermarkExportError.unableToWrite }
        writer.add(videoInput)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
            kCVPixelBufferWidthKey as String: Int(outputSize.width),
            kCVPixelBufferHeightKey as String: Int(outputSize.height),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ])

        let audioInput: AVAssetWriterInput?
        if audioOutput != nil {
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128_000
            ])
            input.expectsMediaDataInRealTime = false
            guard writer.canAdd(input) else { throw VideoWatermarkExportError.unableToWrite }
            writer.add(input)
            audioInput = input
        } else {
            audioInput = nil
        }

        let readerStarted = reader.startReading()
        Logger.videoWatermark.notice_public("watermark export reader start: task=\(task.id.uuidString), started=\(readerStarted), status=\(reader.status.rawValue), error=\(reader.error?.localizedDescription ?? "none")")
        guard readerStarted else { throw reader.error ?? VideoWatermarkExportError.unableToRead }
        let writerStarted = writer.startWriting()
        Logger.videoWatermark.notice_public("watermark export writer start: task=\(task.id.uuidString), started=\(writerStarted), status=\(writer.status.rawValue), error=\(writer.error?.localizedDescription ?? "none")")
        guard writerStarted else { throw writer.error ?? VideoWatermarkExportError.unableToWrite }
        writer.startSession(atSourceTime: timeRange.start)
        Logger.videoWatermark.notice_public("watermark export writer session started: task=\(task.id.uuidString), sourceTime=\(String(format: "%.3f", timeRange.start.seconds))")
        let ciContext = CIContext(options: [.cacheIntermediates: false])
        let producerGroup = DispatchGroup()
        let videoProducerQueue = DispatchQueue(label: "com.valbara.sporreer.videoWatermark.videoProducer", qos: .userInitiated)
        let audioProducerQueue = DispatchQueue(label: "com.valbara.sporreer.videoWatermark.audioProducer", qos: .utility)
        let videoProducerState = VideoWatermarkProducerState()
        let audioProducerState = VideoWatermarkProducerState()
        let audioState = VideoWatermarkAudioAppendState()
        let producerActivity = VideoWatermarkProducerActivity()
        var firstPresentationTime: CMTime?
        var processedFrameCount = 0
        var watermarkFrameCount = 0
        var skippedWatermarkFrameCount = 0
        // 水印内容不需要以 60fps 重绘：速度/海拔/轨迹在 10fps 下已足够平滑。
        // 复用同一张全画幅 overlay，避免每秒创建数百 MB 的位图。
        let watermarkRenderRate = min(10.0, Double(frameRate))
        var cachedOverlayBucket: Int?
        var cachedOverlay: CGImage?
        var generatedOverlayCount = 0
        let audioStartedAt = Date()
        var audioSampleCount = 0
        var audioFirstPresentationTime: Double?
        var audioLastPresentationTime: Double?
        Logger.videoWatermark.notice_public("watermark export overlay cache enabled: task=\(task.id.uuidString), renderRate=\(Int(watermarkRenderRate))fps")
        func finishVideoProducer(_ error: Error? = nil) {
            guard videoProducerState.finish(error: error) else { return }
            videoInput.markAsFinished()
            Logger.videoWatermark.notice_public("watermark export video producer finished: task=\(task.id.uuidString), processedFrames=\(processedFrameCount), error=\(error?.localizedDescription ?? "none"), writerStatus=\(writer.status.rawValue), wallElapsed=\(String(format: "%.2f", Date().timeIntervalSince(exportStartedAt)))s")
            producerGroup.leave()
        }

        func finishAudioProducer(_ error: Error? = nil) {
            guard audioProducerState.finish(error: error) else { return }
            audioInput?.markAsFinished()
            Logger.videoWatermark.notice_public("watermark export audio producer finished: task=\(task.id.uuidString), samples=\(audioState.result?.sampleCount ?? 0), error=\(error?.localizedDescription ?? "none"), writerStatus=\(writer.status.rawValue), wallElapsed=\(String(format: "%.2f", Date().timeIntervalSince(exportStartedAt)))s")
            producerGroup.leave()
        }

        producerGroup.enter()
        Logger.videoWatermark.notice_public("watermark export video producer scheduled: task=\(task.id.uuidString)")
        videoInput.requestMediaDataWhenReady(on: videoProducerQueue) {
            do {
                while videoInput.isReadyForMoreMediaData {
                    try cancellation.checkCancellation()
                    guard let sampleBuffer = videoOutput.copyNextSampleBuffer() else {
                        finishVideoProducer()
                        return
                    }
                    try autoreleasepool {
                        guard let sourceBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
                        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                        if firstPresentationTime == nil {
                            firstPresentationTime = presentationTime
                            Logger.videoWatermark.debug_public("watermark export first frame: task=\(task.id.uuidString), presentationTime=\(String(format: "%.3f", presentationTime.seconds)), expectedSourceOffset=\(String(format: "%.3f", task.media.effectiveVideoStart))")
                        }
                        let relativeVideoTime = max(presentationTime.seconds - (firstPresentationTime?.seconds ?? presentationTime.seconds), 0)
                        let sourceVideoTime = task.media.effectiveVideoStart + relativeVideoTime
                        guard let pool = adaptor.pixelBufferPool else { throw VideoWatermarkExportError.unableToCreatePixelBuffer }
                        var destinationBuffer: CVPixelBuffer?
                        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &destinationBuffer) == kCVReturnSuccess,
                              let destinationBuffer else { throw VideoWatermarkExportError.unableToCreatePixelBuffer }
                        if isHDROutput {
                            CVBufferPropagateAttachments(sourceBuffer, destinationBuffer)
                        } else {
                            configureSDRAttachments(on: destinationBuffer)
                        }
                        let overlayBucket = Int((relativeVideoTime * watermarkRenderRate).rounded(.down))
                        if cachedOverlayBucket != overlayBucket {
                            cachedOverlayBucket = overlayBucket
                            cachedOverlay = VideoWatermarkOverlayRenderer.image(task: task, videoTime: sourceVideoTime, size: outputSize, designSize: sourceSize)
                            if cachedOverlay != nil { generatedOverlayCount += 1 }
                        }
                        let baseImage = CIImage(cvPixelBuffer: sourceBuffer)
                        let composite: CIImage
                        if let cachedOverlay {
                            watermarkFrameCount += 1
                            composite = compositeImage(baseImage: baseImage, overlayImage: cachedOverlay, size: outputSize)
                        } else {
                            skippedWatermarkFrameCount += 1
                            if skippedWatermarkFrameCount == 1 {
                                Logger.videoWatermark.warning_public("watermark export skipped a frame without matching motion: task=\(task.id.uuidString), sourceVideoTime=\(String(format: "%.3f", sourceVideoTime)), workoutRange=\(String(format: "%.3f", task.workout.startTime ?? -1))...\(String(format: "%.3f", task.workout.endTime ?? -1))")
                            }
                            composite = baseImage
                        }
                        if isHDROutput {
                            ciContext.render(composite, to: destinationBuffer)
                        } else if let sdrColorSpace {
                            ciContext.render(composite, to: destinationBuffer, bounds: composite.extent, colorSpace: sdrColorSpace)
                        } else {
                            throw VideoWatermarkExportError.unableToRenderSDR
                        }
                        guard adaptor.append(destinationBuffer, withPresentationTime: presentationTime) else { throw writer.error ?? VideoWatermarkExportError.appendFailed }
                        processedFrameCount += 1
                        producerActivity.recordVideoFrame()
                        onProgress(relativeVideoTime / max(task.media.effectiveDuration, 0.001))
                        if processedFrameCount.isMultiple(of: 300) {
                            ciContext.clearCaches()
                            Logger.videoWatermark.debug_public("watermark export checkpoint: task=\(task.id.uuidString), processedFrames=\(processedFrameCount), generatedOverlays=\(generatedOverlayCount), videoElapsed=\(String(format: "%.2f", relativeVideoTime))s, wallElapsed=\(String(format: "%.2f", Date().timeIntervalSince(exportStartedAt)))s")
                        }
                    }
                }
            } catch {
                finishVideoProducer(error)
            }
        }

        if let audioOutput, let audioInput {
            producerGroup.enter()
            Logger.videoWatermark.notice_public("watermark export audio producer scheduled: task=\(task.id.uuidString)")
            audioInput.requestMediaDataWhenReady(on: audioProducerQueue) {
                do {
                    while audioInput.isReadyForMoreMediaData {
                        try cancellation.checkCancellation()
                        guard let buffer = audioOutput.copyNextSampleBuffer() else {
                            let result = VideoWatermarkAudioAppendResult(
                                sampleCount: audioSampleCount,
                                firstPresentationTime: audioFirstPresentationTime,
                                lastPresentationTime: audioLastPresentationTime,
                                wallElapsed: Date().timeIntervalSince(audioStartedAt)
                            )
                            audioState.complete(with: result)
                            Logger.videoWatermark.notice_public("watermark export audio reached end: task=\(task.id.uuidString), samples=\(audioSampleCount), lastPTS=\(formatOptionalTime(audioLastPresentationTime)), wallElapsed=\(String(format: "%.2f", result.wallElapsed))s; marking audio input finished now")
                            finishAudioProducer()
                            return
                        }
                        let presentationTime = CMSampleBufferGetPresentationTimeStamp(buffer).seconds
                        if audioFirstPresentationTime == nil {
                            audioFirstPresentationTime = presentationTime
                            Logger.videoWatermark.debug_public("watermark export audio first sample: task=\(task.id.uuidString), presentationTime=\(String(format: "%.3f", presentationTime))")
                        }
                        guard audioInput.append(buffer) else { throw writer.error ?? VideoWatermarkExportError.appendFailed }
                        audioSampleCount += 1
                        producerActivity.recordAudioSample()
                        audioLastPresentationTime = presentationTime
                        if audioSampleCount.isMultiple(of: 1_000) {
                            Logger.videoWatermark.debug_public("watermark export audio checkpoint: task=\(task.id.uuidString), samples=\(audioSampleCount), lastPTS=\(String(format: "%.3f", presentationTime)), wallElapsed=\(String(format: "%.2f", Date().timeIntervalSince(audioStartedAt)))s, writerStatus=\(writer.status.rawValue)")
                        }
                    }
                } catch {
                    audioState.fail(with: error)
                    Logger.videoWatermark.error_public("watermark export audio producer failed: task=\(task.id.uuidString), error=\(error.localizedDescription), writerStatus=\(writer.status.rawValue), writerError=\(writer.error?.localizedDescription ?? "none")")
                    finishAudioProducer(error)
                }
            }
        } else {
            Logger.videoWatermark.notice_public("watermark export has no audio pipeline: task=\(task.id.uuidString), audioTrack=\(audioTrack != nil)")
        }

        try waitForMediaProducers(
            producerGroup,
            taskID: task.id,
            reader: reader,
            writer: writer,
            cancellation: cancellation,
            activity: producerActivity,
            cancelProducers: {
                reader.cancelReading()
                writer.cancelWriting()
                videoProducerQueue.async { finishVideoProducer(CancellationError()) }
                if audioInput != nil {
                    audioProducerQueue.async { finishAudioProducer(CancellationError()) }
                }
            }
        )

        if let videoError = videoProducerState.error { throw videoError }
        if let audioError = audioProducerState.error ?? audioState.error { throw audioError }
        Logger.videoWatermark.notice_public("watermark export media producers completed: task=\(task.id.uuidString), processedFrames=\(processedFrameCount), audioSamples=\(audioState.result?.sampleCount ?? 0), readerStatus=\(reader.status.rawValue), writerStatus=\(writer.status.rawValue), wallElapsed=\(String(format: "%.2f", Date().timeIntervalSince(exportStartedAt)))s")
        try cancellation.checkCancellation()
        if reader.status == .failed { throw reader.error ?? VideoWatermarkExportError.unableToRead }
        guard watermarkFrameCount > 0 else {
            Logger.videoWatermark.error_public("watermark export rendered no overlay frames: task=\(task.id.uuidString), processedFrames=\(processedFrameCount), skippedFrames=\(skippedWatermarkFrameCount)")
            throw VideoWatermarkExportError.noWatermarkRendered
        }
        Logger.videoWatermark.notice_public("watermark export inputs were marked finished by producers: task=\(task.id.uuidString), hasAudioInput=\(audioInput != nil), writerStatus=\(writer.status.rawValue), readerStatus=\(reader.status.rawValue)")
        try finish(writer: writer, taskID: task.id)
        Logger.videoWatermark.notice_public("watermark export writer finish returned: task=\(task.id.uuidString), writerStatus=\(writer.status.rawValue), writerError=\(writer.error?.localizedDescription ?? "none"), wallElapsed=\(String(format: "%.2f", Date().timeIntervalSince(exportStartedAt)))s")
        if writer.status != .completed { throw writer.error ?? VideoWatermarkExportError.unableToWrite }
        let count = (try? outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        Logger.videoWatermark.notice_public("watermark export completed: task=\(task.id.uuidString), processedFrames=\(processedFrameCount), overlayFrames=\(watermarkFrameCount), generatedOverlays=\(generatedOverlayCount), skippedFrames=\(skippedWatermarkFrameCount), outputBytes=\(count), wallElapsed=\(String(format: "%.2f", Date().timeIntervalSince(exportStartedAt)))s")
        return VideoWatermarkExportResult(outputByteCount: count)
    }

    private static func compositeImage(baseImage: CIImage, overlayImage: CGImage, size: CGSize) -> CIImage {
        // AVAssetReaderVideoComposition 与 UIGraphicsImageRenderer 在这里产出的位图行序一致。
        // 再翻转会同时颠倒水印位置和轨迹曲线。
        CIImage(cgImage: overlayImage).composited(over: baseImage)
    }

    private static func waitForMediaProducers(_ group: DispatchGroup, taskID: UUID, reader: AVAssetReader, writer: AVAssetWriter, cancellation: VideoWatermarkExportCancellation, activity: VideoWatermarkProducerActivity, cancelProducers: () -> Void) throws {
        let startedAt = Date()
        var lastLoggedAt = startedAt
        while group.wait(timeout: .now() + 0.25) == .timedOut {
            if cancellation.isCancelled {
                Logger.videoWatermark.notice_public("watermark export cancellation closing media producers: task=\(taskID.uuidString), waitElapsed=\(String(format: "%.2f", Date().timeIntervalSince(startedAt)))s, readerStatus=\(reader.status.rawValue), writerStatus=\(writer.status.rawValue)")
                cancelProducers()
                group.wait()
                throw CancellationError()
            }
            let now = Date()
            let snapshot = activity.snapshot
            let idleElapsed = now.timeIntervalSince(snapshot.lastActivityAt)
            if idleElapsed >= 5, now.timeIntervalSince(lastLoggedAt) >= 5 {
                lastLoggedAt = now
                Logger.videoWatermark.warning_public("watermark export media producers idle: task=\(taskID.uuidString), idleElapsed=\(String(format: "%.2f", idleElapsed))s, videoFrames=\(snapshot.videoFrameCount), audioSamples=\(snapshot.audioSampleCount), readerStatus=\(reader.status.rawValue), writerStatus=\(writer.status.rawValue), writerError=\(writer.error?.localizedDescription ?? "none")")
            }
        }
    }

    private static func finish(writer: AVAssetWriter, taskID: UUID) throws {
        let startedAt = Date()
        let semaphore = DispatchSemaphore(value: 0)
        Logger.videoWatermark.notice_public("watermark export writer finish requested: task=\(taskID.uuidString), writerStatus=\(writer.status.rawValue)")
        writer.finishWriting {
            Logger.videoWatermark.notice_public("watermark export writer finish callback: task=\(taskID.uuidString), writerStatus=\(writer.status.rawValue), writerError=\(writer.error?.localizedDescription ?? "none"), waitElapsed=\(String(format: "%.2f", Date().timeIntervalSince(startedAt)))s")
            semaphore.signal()
        }
        while semaphore.wait(timeout: .now() + 5) == .timedOut {
            Logger.videoWatermark.warning_public("watermark export still waiting for writer finish: task=\(taskID.uuidString), waitElapsed=\(String(format: "%.2f", Date().timeIntervalSince(startedAt)))s, writerStatus=\(writer.status.rawValue), writerError=\(writer.error?.localizedDescription ?? "none")")
        }
    }

    private static func formatOptionalTime(_ value: Double?) -> String {
        guard let value else { return "none" }
        return String(format: "%.3f", value)
    }

    private static func makeVideoComposition(track: AVAssetTrack, preferredTransform: CGAffineTransform, sourceSize: CGSize, renderSize: CGSize, frameRate: Int32, duration: CMTime, dynamicRange: VideoWatermarkOutputDynamicRange) -> AVMutableVideoComposition {
        let composition = AVMutableVideoComposition()
        composition.renderSize = renderSize
        composition.frameDuration = CMTime(value: 1, timescale: frameRate)
        if dynamicRange == .sdr {
            // Reader 先将 HDR 原片转换为 Rec.709 SDR，后续 Core Image 合成无需再在 HLG 与 sRGB 间反复转换。
            composition.colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2
            composition.colorTransferFunction = AVVideoTransferFunction_ITU_R_709_2
            composition.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_709_2
        }
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        let scale = min(renderSize.width / max(sourceSize.width, 1), renderSize.height / max(sourceSize.height, 1))
        let scaledTransform = preferredTransform.concatenating(CGAffineTransform(scaleX: scale, y: scale))
        layerInstruction.setTransform(scaledTransform, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        composition.instructions = [instruction]
        return composition
    }

    private static func orientedSize(naturalSize: CGSize, preferredTransform: CGAffineTransform) -> CGSize {
        let transformed = naturalSize.applying(preferredTransform)
        return CGSize(width: abs(transformed.width), height: abs(transformed.height))
    }

    private static func outputSize(sourceSize: CGSize, format: VideoWatermarkOutputFormat) -> CGSize {
        guard sourceSize.width > 0, sourceSize.height > 0 else { return CGSize(width: 1920, height: 1080) }
        let sourceLongEdge = max(sourceSize.width, sourceSize.height)
        let scale = min(format.resolution.longEdge / sourceLongEdge, 1)
        let width = max((sourceSize.width * scale).rounded(), 2)
        let height = max((sourceSize.height * scale).rounded(), 2)
        return CGSize(width: width - width.truncatingRemainder(dividingBy: 2), height: height - height.truncatingRemainder(dividingBy: 2))
    }

    /// SDR 输出不能继承 HDR 原帧的 HLG / BT.2020 附件；否则 Writer 会收到与 Rec.709 设置冲突的像素缓冲。
    private static func configureSDRAttachments(on pixelBuffer: CVPixelBuffer) {
        CVBufferRemoveAllAttachments(pixelBuffer)
        CVBufferSetAttachment(pixelBuffer, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(pixelBuffer, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2, .shouldPropagate)
    }

    private static func outputFileType(for task: VideoWatermarkTask) -> AVFileType {
        task.media.container.lowercased() == "mov" ? .mov : .mp4
    }

    private static func videoSettings(for task: VideoWatermarkTask, size: CGSize, frameRate: Int32, outputFormat: VideoWatermarkOutputFormat) -> [String: Any] {
        let useHEVC = outputFormat.dynamicRange == .hdr || task.media.codec.lowercased().contains("hevc") || task.media.codec.lowercased().contains("hvc")
        let bitrate = max(4_000_000, Int(size.width * size.height * CGFloat(frameRate) * 0.09))
        var compressionProperties: [String: Any] = [
            AVVideoAverageBitRateKey: bitrate,
            AVVideoExpectedSourceFrameRateKey: frameRate,
            AVVideoMaxKeyFrameIntervalKey: frameRate * 2
        ]
        if outputFormat.dynamicRange == .hdr {
            // ProfileLevel 是 VideoToolbox 编码器参数，必须位于 AVVideoCompressionPropertiesKey 内。
            compressionProperties[AVVideoProfileLevelKey] = kVTProfileLevel_HEVC_Main10_AutoLevel
        }
        var settings: [String: Any] = [
            AVVideoCodecKey: useHEVC ? AVVideoCodecType.hevc : AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width.rounded()),
            AVVideoHeightKey: Int(size.height.rounded()),
            AVVideoCompressionPropertiesKey: compressionProperties
        ]
        if outputFormat.dynamicRange == .hdr {
            settings[AVVideoColorPropertiesKey] = [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020
            ]
        } else {
            settings[AVVideoColorPropertiesKey] = [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ]
        }
        return settings
    }
}
