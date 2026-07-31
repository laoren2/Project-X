//
//  VideoWatermarkOverlayRenderer.swift
//  sportsx
//
//  导出和编辑预览共用的轻量水印绘制器。所有坐标均基于归一化布局。
//

import UIKit

enum VideoWatermarkOverlayRenderer {
    private struct MetricPresentation {
        let value: String
        let unit: String
        let icon: String?
        let iconColor: UIColor

        init(value: String, unit: String, icon: String? = nil, iconColor: UIColor = .white) {
            self.value = value
            self.unit = unit
            self.icon = icon
            self.iconColor = iconColor
        }
    }

    /// 编辑态使用真实当前数据计算的内容固有尺寸。数值水印不再保留固定右侧空白。
    static func previewContentSize(for metric: VideoWatermarkMetric, workoutPoints: [VideoWatermarkMotionPoint], paceTimeline: [VideoWatermarkPaceFrame] = [], workoutTime: TimeInterval) -> CGSize {
        let motion = previewMotion(workoutPoints: workoutPoints, workoutTime: workoutTime)
        return intrinsicContentSize(for: metric, motion: motion, paceFrame: paceFrame(in: paceTimeline, at: motion.timestamp))
    }

    /// 以有效视频覆盖的运动数据找出文字水印可能出现的最大尺寸。
    /// 它只用于滑杆上限和拖拽边界，编辑态虚线框仍使用 `previewContentSize` 的真实当前尺寸。
    static func maximumPreviewContentSize(for metric: VideoWatermarkMetric, workoutPoints: [VideoWatermarkMotionPoint], paceTimeline: [VideoWatermarkPaceFrame] = [], workoutStart: TimeInterval, duration: TimeInterval) -> CGSize {
        let start = workoutStart
        let end = start + max(duration, 0)
        var motions = workoutPoints.filter { $0.timestamp >= start && $0.timestamp <= end }
        motions.append(previewMotion(workoutPoints: workoutPoints, workoutTime: workoutStart))
        let sizes = motions.map { motion in
            intrinsicContentSize(for: metric, motion: motion, paceFrame: paceFrame(in: paceTimeline, at: motion.timestamp))
        }
        return sizes.reduce(.zero) { largest, size in
            CGSize(width: max(largest.width, size.width), height: max(largest.height, size.height))
        }
    }

    /// `designSize` 是编辑时布局所基于的原片尺寸。导出缩小分辨率时，水印需随画布等比缩小。
    static func image(task: VideoWatermarkTask, videoTime: TimeInterval, size: CGSize, designSize: CGSize? = nil) -> CGImage? {
        guard let motion = motionPoint(for: task, videoTime: videoTime), size.width > 0, size.height > 0 else { return nil }
        let referenceSize = designSize ?? size
        let drawingScale = min(size.width / max(referenceSize.width, 1), size.height / max(referenceSize.height, 1))
        return image(metrics: task.selectedMetrics, layouts: task.layouts, motion: motion, routePoints: task.workout.points, paceTimeline: task.paceTimeline ?? [], size: size, drawingScale: drawingScale)
    }

    /// 编辑器与导出共用同一绘制路径。预览使用真实轨迹与当前水印片段的数据；
    /// `designSize` 保留视频像素坐标比例，避免小画布把水印放大到和成片不一致的尺寸。
    static func previewImage(metrics: Set<VideoWatermarkMetric>, layouts: [VideoWatermarkMetric: VideoWatermarkLayout], workoutPoints: [VideoWatermarkMotionPoint], paceTimeline: [VideoWatermarkPaceFrame] = [], workoutTime: TimeInterval, size: CGSize, designSize: CGSize) -> CGImage? {
        guard size.width > 0, size.height > 0, designSize.width > 0, designSize.height > 0 else { return nil }
        let fallbackPoints = fallbackMotionPoints
        let routePoints = workoutPoints.count > 1 ? workoutPoints : fallbackPoints
        let motion = previewMotion(workoutPoints: workoutPoints, workoutTime: workoutTime)
        // 以 2x 位图绘制再按点尺寸展示，文本与 SF Symbol 会保持锐利，不会被 SwiftUI 二次放大变形。
        let pixelScale: CGFloat = 2
        let pixelSize = CGSize(width: size.width * pixelScale, height: size.height * pixelScale)
        let scale = min(pixelSize.width / designSize.width, pixelSize.height / designSize.height)
        return image(metrics: metrics, layouts: layouts, motion: motion, routePoints: routePoints, paceTimeline: paceTimeline, size: pixelSize, drawingScale: scale)
    }

    private static func image(metrics: Set<VideoWatermarkMetric>, layouts: [VideoWatermarkMetric: VideoWatermarkLayout], motion: VideoWatermarkMotionPoint, routePoints: [VideoWatermarkMotionPoint], paceTimeline: [VideoWatermarkPaceFrame], size: CGSize, drawingScale: CGFloat) -> CGImage? {
        // `size` 是导出视频的像素尺寸。默认 renderer 会使用设备 Retina scale，生成 2x/3x
        // CGImage 后直接交给 Core Image 会让水印坐标落到视频画布之外。
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            let cgContext = context.cgContext
            cgContext.setAllowsAntialiasing(true)
            cgContext.setShouldAntialias(true)
            for metric in metrics {
                guard let layout = layouts[metric] else { continue }
                draw(metric: metric, layout: layout, motion: motion, routePoints: routePoints, paceFrame: paceFrame(in: paceTimeline, at: motion.timestamp), in: cgContext, size: size, drawingScale: drawingScale)
            }
        }.cgImage
    }

    private static func draw(metric: VideoWatermarkMetric, layout: VideoWatermarkLayout, motion: VideoWatermarkMotionPoint, routePoints: [VideoWatermarkMotionPoint], paceFrame: VideoWatermarkPaceFrame?, in context: CGContext, size: CGSize, drawingScale: CGFloat) {
        // 编辑器已按视频封面尺寸为每个水印限制合法范围；导出不能再使用另一套
        // 固定倍数截断，否则高分辨率视频的预览与成片尺寸会不一致。
        let layoutScale = CGFloat(layout.scale)
        guard layoutScale.isFinite, layoutScale > 0 else { return }
        let scale = layoutScale * drawingScale
        let intrinsicSize = intrinsicContentSize(for: metric, motion: motion, paceFrame: paceFrame)
        let rect = rect(centerX: layout.x, centerY: layout.y, width: intrinsicSize.width * scale, height: intrinsicSize.height * scale, size: size)
        switch metric {
        case .route:
            drawRoute(points: routePoints, currentTimestamp: motion.timestamp, rect: rect, scale: scale, in: context)
        case .speed, .altitude, .heartRate:
            guard let presentation = metricPresentation(for: metric, motion: motion) else { return }
            drawMetric(presentation, rect: rect, scale: scale, in: context)
        case .predictedRank, .pbTime, .pbDistance:
            guard let presentation = pacePresentation(for: metric, frame: paceFrame) else { return }
            drawMetric(presentation, rect: rect, scale: scale, in: context)
        case .logo:
            drawLogo(in: rect, scale: scale)
        }
    }

    private static func drawMetric(_ presentation: MetricPresentation, rect: CGRect, scale: CGFloat, in context: CGContext) {
        let iconFrameSize = presentation.icon.map { iconSize(for: $0, scale: scale) } ?? CGSize.zero
        if let icon = presentation.icon {
            let iconRect = CGRect(x: rect.minX, y: rect.midY - iconFrameSize.height / 2, width: iconFrameSize.width, height: iconFrameSize.height)
            drawSymbol(icon, color: presentation.iconColor, in: iconRect, scale: scale, context: context)
        }
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 26 * scale, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let iconSpacing: CGFloat = presentation.icon == nil ? 0 : 8 * scale
        let valueOrigin = CGPoint(x: rect.minX + iconFrameSize.width + iconSpacing, y: rect.midY - 16 * scale)
        let valueWidth = (presentation.value as NSString).size(withAttributes: valueAttributes).width
        (presentation.value as NSString).draw(at: valueOrigin, withAttributes: valueAttributes)
        if !presentation.unit.isEmpty {
            (presentation.unit as NSString).draw(at: CGPoint(x: valueOrigin.x + valueWidth + 6 * scale, y: rect.midY - 11 * scale), withAttributes: [
                .font: UIFont.systemFont(ofSize: 18 * scale, weight: .semibold),
                .foregroundColor: UIColor.white
            ])
        }
    }

    /// 以 SF Symbol 的 alpha mask 直接填色，避免透明图标的黑色 RGB 在 Core Image 合成或预览缩放时泄漏为细黑边。
    private static func drawSymbol(_ name: String, color: UIColor, in rect: CGRect, scale: CGFloat, context: CGContext?) {
        guard let image = UIImage(
            systemName: name,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 23 * scale, weight: .semibold)
        ), let cgImage = image.cgImage, let context else {
            return
        }
        guard !rect.isEmpty else { return }
        context.saveGState()
        defer { context.restoreGState() }
        // `clip(to:mask:)` 按 Core Graphics 的 y-up 图像坐标解释 mask；UIKit 绘图上下文为 y-down，
        // 因此需围绕图标矩形翻转一次，避免所有 SF Symbol 上下颠倒。
        context.translateBy(x: 0, y: rect.minY + rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.interpolationQuality = .high
        context.clip(to: rect, mask: cgImage)
        context.setFillColor(color.cgColor)
        context.fill(rect)
    }

    private static func drawLogo(in rect: CGRect, scale: CGFloat) {
        guard let icon = UIImage(named: "single_app_icon"), let wordmark = UIImage(named: "app_logo_text") else { return }
        let iconSize = CGSize(width: 30 * scale, height: 30 * scale)
        icon.draw(in: CGRect(origin: CGPoint(x: rect.minX, y: rect.midY - iconSize.height / 2), size: iconSize))
        let maximumWordmarkSize = CGSize(width: 144 * scale, height: 24 * scale)
        let ratio = min(maximumWordmarkSize.width / max(wordmark.size.width, 1), maximumWordmarkSize.height / max(wordmark.size.height, 1))
        let wordmarkSize = CGSize(width: wordmark.size.width * ratio, height: wordmark.size.height * ratio)
        wordmark.draw(in: CGRect(x: rect.minX + 36 * scale, y: rect.midY - wordmarkSize.height / 2, width: wordmarkSize.width, height: wordmarkSize.height))
    }

    private static let fallbackMotionPoints = [
        VideoWatermarkMotionPoint(lat: 31.228, lon: 121.475, speed: 4.8, altitude: 318, heartRate: 142, timestamp: 0),
        VideoWatermarkMotionPoint(lat: 31.232, lon: 121.481, speed: 5.2, altitude: 325, heartRate: 145, timestamp: 5),
        VideoWatermarkMotionPoint(lat: 31.238, lon: 121.478, speed: 5.0, altitude: 322, heartRate: 143, timestamp: 10)
    ]

    private static func previewMotion(workoutPoints: [VideoWatermarkMotionPoint], workoutTime: TimeInterval) -> VideoWatermarkMotionPoint {
        motionPoint(in: workoutPoints, at: workoutTime)
            ?? (workoutPoints.isEmpty ? nil : workoutPoints[workoutPoints.count / 2])
            ?? fallbackMotionPoints[1]
    }

    private static func metricPresentation(for metric: VideoWatermarkMetric, motion: VideoWatermarkMotionPoint) -> MetricPresentation? {
        switch metric {
        case .speed:
            return MetricPresentation(value: String(format: "%.1f", motion.speed * 3.6), unit: "km/h", icon: "speedometer")
        case .altitude:
            return MetricPresentation(value: String(format: "%.0f", motion.altitude), unit: "m", icon: "triangle.fill")
        case .heartRate:
            // 无采样值不能用前后有效值填充，避免将错误心率写入视频。
            let value = motion.heartRate.map { String(format: "%.0f", $0) } ?? "-"
            return MetricPresentation(value: value, unit: "bpm", icon: "heart.fill")
        case .route, .predictedRank, .pbTime, .pbDistance, .logo:
            return nil
        }
    }

    private static func pacePresentation(for metric: VideoWatermarkMetric, frame: VideoWatermarkPaceFrame?) -> MetricPresentation? {
        guard let frame else { return nil }
        switch metric {
        case .predictedRank:
            guard let rank = frame.rank, frame.total > 0 else { return nil }
            return MetricPresentation(value: "#\(rank) / \(frame.total)", unit: "")
        case .pbTime:
            guard let delta = frame.deltaTime else { return nil }
            let ahead = delta >= 0
            return MetricPresentation(
                value: String(format: "%.0f", abs(delta)),
                unit: "s",
                icon: ahead ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill",
                iconColor: ahead ? .green : .red
            )
        case .pbDistance:
            guard let delta = frame.deltaDistance else { return nil }
            let ahead = delta >= 0
            return MetricPresentation(
                value: String(format: "%.0f", abs(delta)),
                unit: "m",
                icon: ahead ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill",
                iconColor: ahead ? .green : .red
            )
        default:
            return nil
        }
    }

    private static func intrinsicContentSize(for metric: VideoWatermarkMetric, motion: VideoWatermarkMotionPoint, paceFrame: VideoWatermarkPaceFrame? = nil) -> CGSize {
        switch metric {
        case .route:
            return CGSize(width: 150, height: 116)
        case .predictedRank, .pbTime, .pbDistance:
            guard let presentation = pacePresentation(for: metric, frame: paceFrame) else { return .zero }
            return metricContentSize(for: presentation)
        case .logo:
            return CGSize(width: 180, height: 30)
        case .speed, .altitude, .heartRate:
            guard let presentation = metricPresentation(for: metric, motion: motion) else { return .zero }
            return metricContentSize(for: presentation)
        }
    }

    private static func metricContentSize(for presentation: MetricPresentation) -> CGSize {
        let valueFont = UIFont.monospacedDigitSystemFont(ofSize: 26, weight: .bold)
        let unitFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
        let valueWidth = (presentation.value as NSString).size(withAttributes: [.font: valueFont]).width
        let unitWidth = (presentation.unit as NSString).size(withAttributes: [.font: unitFont]).width
        let unitSpacing: CGFloat = presentation.unit.isEmpty ? 0 : 6
        let icon = presentation.icon.map { iconSize(for: $0, scale: 1) } ?? CGSize.zero
        let iconSpacing: CGFloat = presentation.icon == nil ? 0 : 8
        return CGSize(
            width: ceil(icon.width + iconSpacing + valueWidth + unitSpacing + unitWidth),
            height: ceil(max(icon.height, valueFont.lineHeight, unitFont.lineHeight))
        )
    }

    private static func iconSize(for icon: String, scale: CGFloat) -> CGSize {
        let maximum = CGSize(width: 23 * scale, height: 23 * scale)
        guard let image = UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 23 * scale, weight: .semibold)) else {
            return maximum
        }
        let ratio = min(maximum.width / max(image.size.width, 1), maximum.height / max(image.size.height, 1))
        return CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
    }

    private static func drawRoute(points: [VideoWatermarkMotionPoint], currentTimestamp: TimeInterval, rect: CGRect, scale: CGFloat, in context: CGContext) {
        guard points.count > 1 else { return }
        let inset = rect.insetBy(dx: 7 * scale, dy: 7 * scale)
        let minLat = points.map(\.lat).min() ?? 0
        let maxLat = points.map(\.lat).max() ?? 0
        let minLon = points.map(\.lon).min() ?? 0
        let maxLon = points.map(\.lon).max() ?? 0
        let latRange = max(maxLat - minLat, 0.000_001)
        let lonRange = max(maxLon - minLon, 0.000_001)
        func position(_ point: VideoWatermarkMotionPoint) -> CGPoint {
            CGPoint(x: inset.minX + CGFloat((point.lon - minLon) / lonRange) * inset.width,
                    y: inset.maxY - CGFloat((point.lat - minLat) / latRange) * inset.height)
        }
        let route = UIBezierPath()
        route.move(to: position(points[0]))
        points.dropFirst().forEach { route.addLine(to: position($0)) }
        UIColor.white.withAlphaComponent(0.45).setStroke()
        route.lineWidth = 4 * scale
        route.lineJoinStyle = .round
        route.lineCapStyle = .round
        route.stroke()

        let completed = points.filter { $0.timestamp <= currentTimestamp }
        if completed.count > 1 {
            let path = UIBezierPath()
            path.move(to: position(completed[0]))
            completed.dropFirst().forEach { path.addLine(to: position($0)) }
            UIColor.orange.setStroke()
            path.lineWidth = 5.5 * scale
            path.lineJoinStyle = .round
            path.lineCapStyle = .round
            path.stroke()
        }
        let current = completed.last ?? points[0]
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(x: position(current).x - 5 * scale, y: position(current).y - 5 * scale, width: 10 * scale, height: 10 * scale))
    }

    private static func motionPoint(for task: VideoWatermarkTask, videoTime: TimeInterval) -> VideoWatermarkMotionPoint? {
        guard let workoutTime = task.overlayRange.workoutTime(for: videoTime) else { return nil }
        return motionPoint(in: task.workout.points, at: workoutTime)
    }

    private static func motionPoint(in points: [VideoWatermarkMotionPoint], at target: TimeInterval) -> VideoWatermarkMotionPoint? {
        guard let first = points.first, let last = points.last, target >= first.timestamp, target <= last.timestamp else { return nil }
        guard let upperIndex = points.firstIndex(where: { $0.timestamp >= target }) else { return last }
        guard upperIndex > 0 else { return points[upperIndex] }
        let lower = points[upperIndex - 1]
        let upper = points[upperIndex]
        let duration = max(upper.timestamp - lower.timestamp, 0.000_001)
        let ratio = min(max((target - lower.timestamp) / duration, 0), 1)
        return VideoWatermarkMotionPoint(
            lat: lower.lat + (upper.lat - lower.lat) * ratio,
            lon: lower.lon + (upper.lon - lower.lon) * ratio,
            speed: lower.speed + (upper.speed - lower.speed) * ratio,
            altitude: lower.altitude + (upper.altitude - lower.altitude) * ratio,
            heartRate: lower.heartRate ?? upper.heartRate,
            timestamp: target
        )
    }

    private static func paceFrame(in frames: [VideoWatermarkPaceFrame], at target: TimeInterval) -> VideoWatermarkPaceFrame? {
        guard let first = frames.first, target >= first.timestamp else { return nil }
        var lo = 0
        var hi = frames.count
        while lo + 1 < hi {
            let mid = (lo + hi) / 2
            if frames[mid].timestamp <= target { lo = mid } else { hi = mid }
        }
        return frames[lo]
    }

    private static func rect(centerX: Double, centerY: Double, width: CGFloat, height: CGFloat, size: CGSize) -> CGRect {
        CGRect(x: CGFloat(centerX) * size.width - width / 2,
               y: CGFloat(centerY) * size.height - height / 2,
               width: width,
               height: height)
    }
}
