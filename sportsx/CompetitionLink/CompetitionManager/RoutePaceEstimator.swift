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
    private let checkpoints: [CheckpointRealtime]    // 有序检查点，定义 route 的规范拓扑
    private let cumS: [Double]                       // 各检查点累计规范弧长（米）
    let routeLength: Double                           // 路线总长
    private let sortedFinishTimes: [Double]          // 升序完赛成绩
    private let pbProfile: SplitProfile?
    private var activeCheckpointIndex = 0             // 当前已确认到达的检查点
    private var segmentProgress = 0.0                 // 当前段内单调进度 [0, 1]
    private var lastProjectionTimestamp: TimeInterval?

    var hasPB: Bool { pbProfile != nil }
    var leaderboardCount: Int { sortedFinishTimes.count }

    init?(routePoints: [RoutePointRealtime], finishTimes: [Double], pbProfile: SplitProfile?) {
        let points = routePoints.compactMap { point -> CheckpointRealtime? in
            if case .checkpoint(let checkpoint) = point { return checkpoint }
            return nil
        }
        guard points.count >= 2 else { return nil }
        self.checkpoints = points

        var s: [Double] = [0]
        for i in 1..<points.count {
            s.append(s[i - 1] + GeographyTool.haversineDistance(
                lat1: points[i - 1].lat, lon1: points[i - 1].lng,
                lat2: points[i].lat, lon2: points[i].lng))
        }
        self.cumS = s
        self.routeLength = s.last ?? 0
        guard routeLength > 0 else { return nil }

        self.sortedFinishTimes = finishTimes.sorted()
        self.pbProfile = pbProfile
    }

    /// 投影只在当前检查点段内进行。阶段只能由实时检查点状态或回放事件推进，
    /// 因此环线/折返时不会被吸附到地理上接近的未来段。
    func project(
        _ coord: CLLocationCoordinate2D,
        completedCheckpointIndex: Int? = nil,
        timestamp: TimeInterval? = nil,
        sport: SportName? = nil
    ) -> Double {
        if let completedCheckpointIndex, completedCheckpointIndex > activeCheckpointIndex {
            activeCheckpointIndex = min(completedCheckpointIndex, checkpoints.count - 1)
            segmentProgress = 0
        }
        guard activeCheckpointIndex < checkpoints.count - 1 else { return routeLength }

        let start = checkpoints[activeCheckpointIndex]
        let end = checkpoints[activeCheckpointIndex + 1]
        let mPerDegLat = 111320.0
        let mPerDegLon = 111320.0 * cos(coord.latitude * .pi / 180)
        let ax = (start.lng - coord.longitude) * mPerDegLon
        let ay = (start.lat - coord.latitude) * mPerDegLat
        let bx = (end.lng - coord.longitude) * mPerDegLon
        let by = (end.lat - coord.latitude) * mPerDegLat
        let dx = bx - ax, dy = by - ay
        let segmentSquared = dx * dx + dy * dy
        var projected = segmentSquared <= 1e-9 ? 0 : max(0, min(1, (-ax * dx - ay * dy) / segmentSquared))

        // 仅用于抑制单个漂移点把本段进度突然推到很后面；真实到达下一个检查点时
        // 会通过 completedCheckpointIndex 精确越段，不受此限速影响。
        if let timestamp, let previousTimestamp = lastProjectionTimestamp, timestamp > previousTimestamp {
            let maxSpeed = sport == .Running ? 10.0 : 25.0
            let segmentLength = max(cumS[activeCheckpointIndex + 1] - cumS[activeCheckpointIndex], 1)
            let allowedAdvance = max(30.0, maxSpeed * (timestamp - previousTimestamp)) / segmentLength
            projected = min(projected, segmentProgress + allowedAdvance)
        }
        segmentProgress = max(segmentProgress, projected)
        lastProjectionTimestamp = timestamp ?? lastProjectionTimestamp
        return cumS[activeCheckpointIndex] + segmentProgress * (cumS[activeCheckpointIndex + 1] - cumS[activeCheckpointIndex])
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
        guard d > 1, routeLength > 0 else { return nil }
        let proj = tEff * routeLength / d
        // 整个排行榜都视为对手，统计严格快于我的人数 → 我的名次；total = 榜单条数 + 我，恒定不变
        var lo = 0, hi = sortedFinishTimes.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if sortedFinishTimes[mid] < proj { lo = mid + 1 } else { hi = mid }
        }
        return (lo + 1, sortedFinishTimes.count + 1)
    }

    /// 完赛后以真实有效成绩直接排名，不能再使用进行中的距离外推。
    func finalRank(effectiveTime: Double) -> (rank: Int, total: Int) {
        var lo = 0, hi = sortedFinishTimes.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if sortedFinishTimes[mid] < effectiveTime { lo = mid + 1 } else { hi = mid }
        }
        return (lo + 1, sortedFinishTimes.count + 1)
    }
}
