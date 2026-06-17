//
//  RoutePaceEstimator.swift
//  sportsx
//
//  运动中实时「预测完赛名次」+「与个人最佳（PB）对比」的计算器。
//  把 route 几何按弧长参数化成一把「尺子」，核心原语是 project(坐标)->沿路里程 d。
//  - 预测名次：按当前有效用时外推完赛时间，二分进有序成绩。
//  - 自我对比：用 PB 的 split profile（里程->用时曲线）做 f(d)-t 与 d-g(t)。
//
//  Created by Claude on 2026/6/16.
//

import Foundation
import CoreLocation


// 与服务端 split profile 对应：{L, N, splits}
struct SplitProfile: Codable {
    let L: Double           // 路线总长（米）
    let N: Int              // 里程桩数量
    let splits: [Double]    // N+1 个里程桩处的有效用时（splits[0]=0，splits[N]=有效完赛时间）
}

// 开赛基线接口响应
struct PaceBaselineResponse: Codable {
    let finish_times: [Double]      // 按用时升序的完赛成绩
    let pb_profile: SplitProfile?   // 个人最佳的 split profile（无则 nil）
}


final class RoutePaceEstimator {
    private let vertices: [CLLocationCoordinate2D]   // route 折线顶点
    private let cumS: [Double]                       // 各顶点累计弧长（米）
    let routeLength: Double                           // 路线总长
    private let sortedFinishTimes: [Double]          // 升序完赛成绩
    private let pbProfile: SplitProfile?
    private var dPrev: Double = 0                     // 上一刻里程（单调前进）

    var hasPB: Bool { pbProfile != nil }
    var leaderboardCount: Int { sortedFinishTimes.count }

    init?(routePoints: [RoutePointRealtime], finishTimes: [Double], pbProfile: SplitProfile?) {
        let verts = RoutePaceEstimator.extractVertices(routePoints)
        guard verts.count >= 2 else { return nil }
        self.vertices = verts

        var s: [Double] = [0]
        for i in 1..<verts.count {
            s.append(s[i - 1] + GeographyTool.haversineDistance(
                lat1: verts[i - 1].latitude, lon1: verts[i - 1].longitude,
                lat2: verts[i].latitude, lon2: verts[i].longitude))
        }
        self.cumS = s
        self.routeLength = s.last ?? 0
        guard routeLength > 0 else { return nil }

        self.sortedFinishTimes = finishTimes.sorted()
        self.pbProfile = pbProfile
    }

    // 从 routePoints 取出有序折线顶点（checkpoint + segment 点），去重相邻重复点
    static func extractVertices(_ routePoints: [RoutePointRealtime]) -> [CLLocationCoordinate2D] {
        var out: [CLLocationCoordinate2D] = []
        for rp in routePoints {
            switch rp {
            case .checkpoint(let cp):
                out.append(CLLocationCoordinate2D(latitude: cp.lat, longitude: cp.lng))
            case .segment(let seg):
                out.append(contentsOf: seg.points)
            }
        }
        var deduped: [CLLocationCoordinate2D] = []
        for v in out {
            if let last = deduped.last, last.latitude == v.latitude, last.longitude == v.longitude { continue }
            deduped.append(v)
        }
        return deduped
    }

    // 把坐标投到折线垂距最近的段，返回沿路弧长（米）。单调前进窗口，处理来回绕。
    func project(_ coord: CLLocationCoordinate2D, back: Double = 30, ahead: Double = 500) -> Double {
        let lo = dPrev - back
        let hi = dPrev + ahead
        let mPerDegLat = 111320.0
        let mPerDegLon = 111320.0 * cos(coord.latitude * .pi / 180)
        var bestPerp = Double.greatestFiniteMagnitude
        var bestArc = dPrev
        for k in 0..<(vertices.count - 1) {
            let sa = cumS[k], sb = cumS[k + 1]
            if sb < lo || sa > hi { continue }
            // 以当前坐标为原点的局部平面（米）
            let ax = (vertices[k].longitude - coord.longitude) * mPerDegLon
            let ay = (vertices[k].latitude - coord.latitude) * mPerDegLat
            let bx = (vertices[k + 1].longitude - coord.longitude) * mPerDegLon
            let by = (vertices[k + 1].latitude - coord.latitude) * mPerDegLat
            let dx = bx - ax, dy = by - ay
            let seg2 = dx * dx + dy * dy
            let t = seg2 <= 1e-9 ? 0 : max(0, min(1, (-ax * dx - ay * dy) / seg2))
            let px = ax + t * dx, py = ay + t * dy
            let perp = (px * px + py * py).squareRoot()
            if perp < bestPerp {
                bestPerp = perp
                bestArc = sa + t * (sb - sa)
            }
        }
        dPrev = max(bestArc, dPrev)
        return dPrev
    }

    // f(d)：PB 在里程 d 处的有效用时
    func pbTime(atDistance d: Double) -> Double? {
        guard let p = pbProfile, p.N > 0, p.splits.count >= 2, p.L > 0 else { return nil }
        let step = p.L / Double(p.N)
        guard step > 0 else { return nil }
        let clamped = max(0, min(d, p.L))
        let idx = max(0, min(Int(clamped / step), p.splits.count - 2))
        let d0 = Double(idx) * step
        let r = max(0, min(1, (clamped - d0) / step))
        return p.splits[idx] + r * (p.splits[idx + 1] - p.splits[idx])
    }

    // g(t)：PB 在用时 t 时所处里程
    func pbDistance(atTime t: Double) -> Double? {
        guard let p = pbProfile, p.N > 0, p.splits.count >= 2, p.L > 0 else { return nil }
        let splits = p.splits
        if t <= splits.first! { return 0 }
        if t >= splits.last! { return p.L }
        let step = p.L / Double(p.N)
        var lo = 0, hi = splits.count - 1
        while lo + 1 < hi {
            let mid = (lo + hi) / 2
            if splits[mid] <= t { lo = mid } else { hi = mid }
        }
        let t0 = splits[lo], t1 = splits[lo + 1]
        let r = t1 > t0 ? max(0, min(1, (t - t0) / (t1 - t0))) : 0
        return (Double(lo) + r) * step
    }

    // 预测名次：按当前有效用时线性外推完赛时间，二分进有序成绩
    func projectedRank(effectiveTime tEff: Double, currentDistance d: Double) -> (rank: Int, total: Int)? {
        guard d > 1, routeLength > 0, !sortedFinishTimes.isEmpty else { return nil }
        let proj = tEff * routeLength / d
        var lo = 0, hi = sortedFinishTimes.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if sortedFinishTimes[mid] < proj { lo = mid + 1 } else { hi = mid }
        }
        let rank = lo + 1
        return (rank, max(sortedFinishTimes.count, rank))
    }
}
