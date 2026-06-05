//
//  ShareTrackShape.swift
//  sportsx
//
//  把运动轨迹坐标投影到本地矩形内、做平滑后描边的矢量轨迹 Shape，
//  用作分享图上可换色、可拖拽缩放的轨迹元素（与地图无关）。
//

import SwiftUI
import CoreLocation

struct ShareTrackShape: Shape {
    let coordinates: [CLLocationCoordinate2D]
    /// 归一化时四周留白比例
    var inset: CGFloat = 0.08

    func path(in rect: CGRect) -> Path {
        guard coordinates.count > 1 else { return Path() }

        // 1. 等距投影：经度按中心纬度缩放，纬度直接用，得到近似等比的平面坐标
        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }
        let lat0 = (lats.min()! + lats.max()!) / 2
        let cosLat = cos(lat0 * .pi / 180)
        var planar = coordinates.map { CGPoint(x: $0.longitude * cosLat, y: $0.latitude) }

        // 点过多时按步长抽稀，降低绘制成本同时保留形状
        if planar.count > 400 {
            let step = Int(ceil(Double(planar.count) / 400.0))
            var sampled: [CGPoint] = []
            var i = 0
            while i < planar.count { sampled.append(planar[i]); i += step }
            if let last = planar.last, sampled.last != last { sampled.append(last) }
            planar = sampled
        }

        // 2. 归一化到 rect（保持长宽比、居中、y 翻转：北→上）
        let xs = planar.map { $0.x }, ys = planar.map { $0.y }
        let minX = xs.min()!, maxX = xs.max()!
        let minY = ys.min()!, maxY = ys.max()!
        let spanX = max(maxX - minX, 1e-9), spanY = max(maxY - minY, 1e-9)

        let drawRect = rect.insetBy(dx: rect.width * inset, dy: rect.height * inset)
        let scale = min(drawRect.width / spanX, drawRect.height / spanY)
        let contentW = spanX * scale, contentH = spanY * scale
        let ox = drawRect.minX + (drawRect.width - contentW) / 2
        let oy = drawRect.minY + (drawRect.height - contentH) / 2

        var pts = planar.map { p in
            CGPoint(x: ox + (p.x - minX) * scale,
                    y: oy + (maxY - p.y) * scale)
        }

        // 3. 轻度滑动平均，弱化 GPS 抖动
        pts = movingAverage(pts, window: 5)

        // 4. Catmull-Rom 转三次贝塞尔，输出平滑曲线
        return catmullRomPath(points: pts)
    }

    private func movingAverage(_ points: [CGPoint], window: Int) -> [CGPoint] {
        guard points.count > window, window > 1 else { return points }
        let half = window / 2
        var result: [CGPoint] = []
        result.reserveCapacity(points.count)
        for i in 0..<points.count {
            let lo = max(0, i - half), hi = min(points.count - 1, i + half)
            var sx: CGFloat = 0, sy: CGFloat = 0
            for j in lo...hi { sx += points[j].x; sy += points[j].y }
            let n = CGFloat(hi - lo + 1)
            result.append(CGPoint(x: sx / n, y: sy / n))
        }
        return result
    }

    private func catmullRomPath(points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }
        guard points.count > 2 else {
            path.move(to: points[0]); path.addLine(to: points[1]); return path
        }
        path.move(to: points[0])
        for i in 0..<(points.count - 1) {
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(i + 2, points.count - 1)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6.0, y: p1.y + (p2.y - p0.y) / 6.0)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6.0, y: p2.y - (p3.y - p1.y) / 6.0)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        return path
    }
}
