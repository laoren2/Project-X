//
//  MiniTrackView.swift
//  sportsx
//
//  小型运动轨迹缩略图：把（服务端已降采样的）坐标点归一化绘制成折线，
//  用于训练历史卡片等处的轻量轨迹预览，不依赖 MapKit、开销极小。
//

import SwiftUI
import CoreLocation


struct MiniTrackView: View {
    let coordinates: [CLLocationCoordinate2D]
    var lineColor: Color = .orange
    var lineWidth: CGFloat = 1.5

    var body: some View {
        GeometryReader { geo in
            if coordinates.count >= 2 {
                trackPath(in: geo.size)
                    .stroke(
                        lineColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
            } else {
                // 无轨迹时的占位，保持卡片布局尺寸稳定
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.thirdText.opacity(0.4))
                    .padding(4)
            }
        }
    }

    private func trackPath(in size: CGSize) -> Path {
        // 经度按纬度余弦压缩，避免高纬地区轨迹形状被横向拉伸失真
        let meanLat = coordinates.map { $0.latitude }.reduce(0, +) / Double(coordinates.count)
        let cosLat = max(0.01, cos(meanLat * .pi / 180))

        let points = coordinates.map { CGPoint(x: $0.longitude * cosLat, y: $0.latitude) }
        let xs = points.map { $0.x }
        let ys = points.map { $0.y }
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else {
            return Path()
        }
        let spanX = max(maxX - minX, 1e-9)
        let spanY = max(maxY - minY, 1e-9)

        let inset: CGFloat = lineWidth + 1
        let w = max(size.width - inset * 2, 1)
        let h = max(size.height - inset * 2, 1)
        // 等比缩放，保持轨迹真实长宽比并居中
        let scale = min(w / spanX, h / spanY)
        let drawW = spanX * scale
        let drawH = spanY * scale
        let offsetX = inset + (w - drawW) / 2
        let offsetY = inset + (h - drawH) / 2

        func mapPoint(_ p: CGPoint) -> CGPoint {
            let x = offsetX + (p.x - minX) * scale
            // 纬度向上为正、屏幕 y 向下，需翻转
            let y = offsetY + (maxY - p.y) * scale
            return CGPoint(x: x, y: y)
        }

        var path = Path()
        path.move(to: mapPoint(points[0]))
        for p in points.dropFirst() {
            path.addLine(to: mapPoint(p))
        }
        return path
    }
}
