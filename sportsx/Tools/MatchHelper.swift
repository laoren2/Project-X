//
//  MatchHelper.swift
//  sportsx
//
//  Created by 任杰 on 2025/11/14.
//

import Foundation


struct RunningPathPointTool {
    // 采样处理比赛原始路径数据，便于展示
    static func computeSamplePoints(pathData: [RunningPathPoint]) -> [RunningSamplePathPoint] {
        guard !pathData.isEmpty else { return [] }
        if pathData.count <= 80 {
            // 当点数不超过80时，直接将每个点转换为区间相同的TestSamplePathPoint
            return pathData.map { p in
                RunningSamplePathPoint(
                    speed_avg: max(3.6 * p.base.speed, 0),
                    altitude_avg: p.base.altitude,
                    heart_rate_min: p.base.heart_rate,
                    heart_rate_max: p.base.heart_rate,
                    power_avg: p.power,
                    step_cadence_avg: p.step_cadence,
                    vertical_amplitude_avg: p.vertical_amplitude,
                    touchdown_time_avg: p.touchdown_time,
                    step_size_avg: p.step_size,
                    step_count_avg: 20.0 * p.estimate_step_count,
                    timestamp_min: p.base.timestamp,
                    timestamp_max: p.base.timestamp
                )
            }
        }
        // 当点数超过80时，按时间段采样，将数据划分为80段
        let minTime = pathData.first!.base.timestamp
        let maxTime = pathData.last!.base.timestamp
        let interval = (maxTime - minTime) / 80.0
        var segments: [[RunningPathPoint]] = Array(repeating: [], count: 80)
        
        for point in pathData {
            let index = min(Int((point.base.timestamp - minTime) / interval), 79)
            segments[index].append(point)
        }
        
        var samples: [RunningSamplePathPoint] = []
        for segment in segments {
            if segment.isEmpty {
                samples.append(RunningSamplePathPoint(
                    speed_avg: 0,
                    altitude_avg: 0,
                    heart_rate_min: nil,
                    heart_rate_max: nil,
                    power_avg: nil,
                    step_cadence_avg: nil,
                    vertical_amplitude_avg: nil,
                    touchdown_time_avg: nil,
                    step_size_avg: nil,
                    step_count_avg: 0,
                    timestamp_min: 0,
                    timestamp_max: 0
                ))
            } else {
                // 1. 计算路径总长度（单位：米）
                var totalDistance: Double = 0
                for i in 0..<(segment.count - 1) {
                    let p1 = segment[i]
                    let p2 = segment[i + 1]
                    totalDistance += GeographyTool.haversineDistance(
                        lat1: p1.base.lat, lon1: p1.base.lon,
                        lat2: p2.base.lat, lon2: p2.base.lon
                    )
                }
                
                // 2. 计算时间差
                let duration = max(segment.last!.base.timestamp - segment.first!.base.timestamp, 0.0001)
                
                // 3. 平均速度（km/h）
                let avgSpeed = segment.count == 1 ? max(segment[0].base.speed * 3.6, 0) : min((totalDistance / duration) * 3.6, 36.0)
                
                // 4. 海拔、心率和时间戳
                let altitudes = segment.map { $0.base.altitude }
                let heartRates = segment.compactMap { $0.base.heart_rate }
                let timestamps = segment.map { $0.base.timestamp }
                
                // 5. 功率和踏频
                let powers = segment.compactMap { $0.power }
                var powerAvg: Double? = 0.0
                if !powers.isEmpty {
                    powerAvg = powers.reduce(0, +) / Double(powers.count)
                } else {
                    powerAvg = nil
                }
                
                let stepCadences = segment.compactMap { $0.step_cadence }
                var stepCadenceAvg: Double? = 0.0
                if !stepCadences.isEmpty {
                    stepCadenceAvg = stepCadences.reduce(0, +) / Double(stepCadences.count)
                } else {
                    stepCadenceAvg = nil
                }
                
                let verticalAmplitudes = segment.compactMap { $0.vertical_amplitude }
                var verticalAmplitudeAvg: Double? = 0.0
                if !verticalAmplitudes.isEmpty {
                    verticalAmplitudeAvg = verticalAmplitudes.reduce(0, +) / Double(verticalAmplitudes.count)
                } else {
                    verticalAmplitudeAvg = nil
                }
                
                let touchdownTimes = segment.compactMap { $0.touchdown_time }
                var touchdownTimeAvg: Double? = 0.0
                if !touchdownTimes.isEmpty {
                    touchdownTimeAvg = touchdownTimes.reduce(0, +) / Double(touchdownTimes.count)
                } else {
                    touchdownTimeAvg = nil
                }
                
                let stepSizes = segment.compactMap { $0.step_size }
                var stepSizeAvg: Double? = 0.0
                if !stepSizes.isEmpty {
                    stepSizeAvg = stepSizes.reduce(0, +) / Double(stepSizes.count)
                } else {
                    stepSizeAvg = nil
                }
                
                let stepCounts = segment.map { $0.estimate_step_count }
                
                samples.append(RunningSamplePathPoint(
                    speed_avg: avgSpeed,
                    altitude_avg: altitudes.reduce(0, +) / Double(altitudes.count),
                    heart_rate_min: heartRates.min(),
                    heart_rate_max: heartRates.max(),
                    power_avg: powerAvg,
                    step_cadence_avg: stepCadenceAvg,
                    vertical_amplitude_avg: verticalAmplitudeAvg,
                    touchdown_time_avg: touchdownTimeAvg,
                    step_size_avg: stepSizeAvg,
                    step_count_avg: 20.0 * stepCounts.reduce(0, +) / Double(stepCounts.count),
                    timestamp_min: timestamps.min() ?? 0,
                    timestamp_max: timestamps.max() ?? 0
                ))
            }
        }
        // speed_avg 异常值处理
        if samples.count >= 3 {
            var fixed: [RunningSamplePathPoint] = samples
            for i in 1..<(samples.count - 1) {
                let left = samples[i - 1].speed_avg
                let mid = samples[i].speed_avg
                let right = samples[i + 1].speed_avg
                let maxNeighbor = max(left, right)
                if mid > 15 && maxNeighbor > 0 && mid > maxNeighbor * 3 {
                    let newSpeed = (mid + (left + right) / 2) / 2
                    fixed[i].speed_avg = newSpeed
                }
            }
            samples = fixed
        }
        return samples
    }
}

struct BikePathPointTool {
    // 采样处理比赛原始路径数据，便于展示
    static func computeSamplePoints(pathData: [BikePathPoint]) -> [BikeSamplePathPoint] {
        guard !pathData.isEmpty else { return [] }
        if pathData.count <= 80 {
            // 当点数不超过80时，直接将每个点转换为区间相同的TestSamplePathPoint
            return pathData.map { p in
                BikeSamplePathPoint(
                    speed_avg: max(3.6 * p.base.speed, 0),
                    altitude_avg: p.base.altitude,
                    heart_rate_min: p.base.heart_rate,
                    heart_rate_max: p.base.heart_rate,
                    power_avg: p.power,
                    pedal_cadence_avg: p.pedal_cadence,
                    pedal_count_avg: p.estimate_pedal_count,
                    timestamp_min: p.base.timestamp,
                    timestamp_max: p.base.timestamp
                )
            }
        }
        // 当点数超过80时，按时间段采样，将数据划分为80段
        let minTime = pathData.first!.base.timestamp
        let maxTime = pathData.last!.base.timestamp
        let interval = (maxTime - minTime) / 80.0
        var segments: [[BikePathPoint]] = Array(repeating: [], count: 80)
        
        for point in pathData {
            let index = min(Int((point.base.timestamp - minTime) / interval), 79)
            segments[index].append(point)
        }
        
        var samples: [BikeSamplePathPoint] = []
        for segment in segments {
            if segment.isEmpty {
                samples.append(BikeSamplePathPoint(
                    speed_avg: 0,
                    altitude_avg: 0,
                    heart_rate_min: nil,
                    heart_rate_max: nil,
                    power_avg: nil,
                    pedal_cadence_avg: nil,
                    pedal_count_avg: 0,
                    timestamp_min: 0,
                    timestamp_max: 0
                ))
            } else {
                // 1. 计算路径总长度（单位：米）
                var totalDistance: Double = 0
                for i in 0..<(segment.count - 1) {
                    let p1 = segment[i]
                    let p2 = segment[i + 1]
                    totalDistance += GeographyTool.haversineDistance(
                        lat1: p1.base.lat, lon1: p1.base.lon,
                        lat2: p2.base.lat, lon2: p2.base.lon
                    )
                }
                
                // 2. 计算时间差
                let duration = max(segment.last!.base.timestamp - segment.first!.base.timestamp, 0.0001)
                
                // 3. 平均速度（km/h）
                let avgSpeed = segment.count == 1 ? max(segment[0].base.speed * 3.6, 0) : min((totalDistance / duration) * 3.6, 100.0)
                
                // 4. 海拔、心率和时间戳
                let altitudes = segment.map { $0.base.altitude }
                let heartRates = segment.compactMap { $0.base.heart_rate }
                let timestamps = segment.map { $0.base.timestamp }
                
                // 5. 功率和踏频
                let powers = segment.compactMap { $0.power }
                var powerAvg: Double? = 0.0
                if !powers.isEmpty {
                    powerAvg = powers.reduce(0, +) / Double(powers.count)
                } else {
                    powerAvg = nil
                }
                
                let pedalCadences = segment.compactMap { $0.pedal_cadence }
                var pedalCadenceAvg: Double? = 0.0
                if !pedalCadences.isEmpty {
                    pedalCadenceAvg = pedalCadences.reduce(0, +) / Double(pedalCadences.count)
                } else {
                    pedalCadenceAvg = nil
                }
                
                let pedalCounts = segment.map { $0.estimate_pedal_count }
                
                samples.append(BikeSamplePathPoint(
                    speed_avg: avgSpeed,
                    altitude_avg: altitudes.reduce(0, +) / Double(altitudes.count),
                    heart_rate_min: heartRates.min(),
                    heart_rate_max: heartRates.max(),
                    power_avg: powerAvg,
                    pedal_cadence_avg: pedalCadenceAvg,
                    pedal_count_avg: pedalCounts.reduce(0, +) / Double(pedalCounts.count),
                    timestamp_min: timestamps.min() ?? 0,
                    timestamp_max: timestamps.max() ?? 0
                ))
            }
        }
        // speed_avg 异常值处理
        if samples.count >= 3 {
            var fixed: [BikeSamplePathPoint] = samples
            for i in 1..<(samples.count - 1) {
                let left = samples[i - 1].speed_avg
                let mid = samples[i].speed_avg
                let right = samples[i + 1].speed_avg
                let maxNeighbor = max(left, right)
                if mid > 50 && maxNeighbor > 0 && mid > maxNeighbor * 3 {
                    let newSpeed = (mid + (left + right) / 2) / 2
                    fixed[i].speed_avg = newSpeed
                }
            }
            samples = fixed
        }
        return samples
    }
}
