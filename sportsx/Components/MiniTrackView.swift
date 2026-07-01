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
    /// 按活动段（segment）分组的坐标：段间为暂停缺口，各段独立成线、绝不跨段连接。
    /// race/route 恒为单段；free training 暂停后会拆成多段。
    let segments: [[CLLocationCoordinate2D]]
    var lineColor: Color = .orange
    var lineWidth: CGFloat = 1.5

    // 展平后的全部坐标，用于归一化取景与占位判断
    private var allCoordinates: [CLLocationCoordinate2D] { segments.flatMap { $0 } }

    var body: some View {
        GeometryReader { geo in
            if allCoordinates.count >= 2 {
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
        let coordinates = allCoordinates
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

        func mapPoint(_ coord: CLLocationCoordinate2D) -> CGPoint {
            let px = coord.longitude * cosLat
            let py = coord.latitude
            let x = offsetX + (px - minX) * scale
            // 纬度向上为正、屏幕 y 向下，需翻转
            let y = offsetY + (maxY - py) * scale
            return CGPoint(x: x, y: y)
        }

        var path = Path()
        // 各活动段独立连线，段间（暂停缺口）不连接
        for seg in segments where seg.count >= 2 {
            path.move(to: mapPoint(seg[0]))
            for c in seg.dropFirst() {
                path.addLine(to: mapPoint(c))
            }
        }
        return path
    }
}
