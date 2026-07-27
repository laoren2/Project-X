//
//  VideoWatermarkPaceTimelineBuilder.swift
//  sportsx
//
//  将完赛时冻结的榜单/PB基线与记录轨迹重放为可离线导出的视频水印时间线。
//

import Foundation
import CoreLocation

enum VideoWatermarkPaceTimelineBuilder {
    static func make(snapshot: VideoWatermarkPaceSnapshot?, workout: VideoWatermarkWorkoutSnapshot) -> [VideoWatermarkPaceFrame] {
        guard let snapshot,
              workout.points.count > 1,
              let estimator = RoutePaceEstimator(
                routePoints: [RoutePoint](routeData: snapshot.route_data).toRealtimePoints(),
                finishTimes: snapshot.finish_times,
                pbProfile: snapshot.pb_profile
              ),
              let start = workout.points.first?.timestamp else {
            return []
        }

        let bonusPoints = (workout.pacePoints ?? []).sorted { $0.timestamp < $1.timestamp }
        var bonusIndex = 0
        var currentBonus = 0.0
        var lastOutputTimestamp = -Double.infinity
        var frames: [VideoWatermarkPaceFrame] = []

        for point in workout.points.sorted(by: { $0.timestamp < $1.timestamp }) {
            // 与实时页一样约每秒发布一次；导出时直接读取该离散显示状态。
            guard point.timestamp - lastOutputTimestamp >= 1 else { continue }
            while bonusIndex < bonusPoints.count && bonusPoints[bonusIndex].timestamp <= point.timestamp {
                currentBonus = bonusPoints[bonusIndex].cumulativeCardBonus
                bonusIndex += 1
            }
            let elapsed = max(0, point.timestamp - start)
            let effectiveTime = max(0, elapsed - currentBonus)
            let distance = estimator.project(CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon))
            let rank = estimator.projectedRank(effectiveTime: effectiveTime, currentDistance: distance)
            let deltaTime = estimator.pbTime(atDistance: distance).map { $0 - effectiveTime }
            let deltaDistance = estimator.pbDistance(atTime: effectiveTime).map { distance - $0 }
            frames.append(VideoWatermarkPaceFrame(
                timestamp: point.timestamp,
                rank: rank?.rank,
                total: rank?.total ?? 0,
                deltaTime: deltaTime,
                deltaDistance: deltaDistance
            ))
            lastOutputTimestamp = point.timestamp
        }
        return frames
    }
}
