//
//  RankRingView.swift
//  sportsx_Watch Watch App
//
//  race/route 预测名次环：3/4 橙色圆环（缺口居中到底部）+ 进度末端圆点。
//  填充比例 fraction（0..1）越大越满；动画由调用方控制。
//

import SwiftUI

struct RankRingView: View {
    var fraction: Double

    private let line: CGFloat = 7
    private let pad: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let r = min(geo.size.width, geo.size.height) / 2 - pad
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                // 轨道
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.orange.opacity(0.2), style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .frame(width: r * 2, height: r * 2)
                    .position(c)
                // 进度
                Circle()
                    .trim(from: 0, to: 0.75 * fraction)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .frame(width: r * 2, height: r * 2)
                    .position(c)
                // 进度末端圆点
                if fraction > 0.001 {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: line + 6, height: line + 6)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .position(endPoint(c: c, r: r))
                }
            }
            .rotationEffect(.degrees(135))
        }
    }

    // 进度弧末端坐标（未旋转坐标系：0=3点钟，顺时针）
    private func endPoint(c: CGPoint, r: CGFloat) -> CGPoint {
        let angle = 2 * Double.pi * 0.75 * fraction
        return CGPoint(x: c.x + r * CGFloat(cos(angle)),
                       y: c.y + r * CGFloat(sin(angle)))
    }
}
