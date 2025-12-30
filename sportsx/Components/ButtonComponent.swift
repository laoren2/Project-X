//
//  ButtonComponent.swift
//  sportsx
//
//  Created by 任杰 on 2025/7/14.
//

import SwiftUI


// todo: 添加按下效果
struct CommonTextButton: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Text(LocalizedStringKey(text))
            .exclusiveTouchTapGesture {
                action()
            }
    }
}

struct CommonIconButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Image(systemName: icon)
            .exclusiveTouchTapGesture {
                action()
            }
    }
}



// 沿着 Capsule 外边框绘制的进度环
struct CapsuleProgressShape: Shape {
    var progress: CGFloat // 0~1 之间

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let radius = rect.height / 2
        let width = rect.width
        let height = rect.height

        // Capsule 总长度 = 两个半圆 + 中间矩形边长
        let circumference = 2 * .pi * radius + (width - height) * 2

        var remaining = circumference * progress

        // 从顶部中心开始
        // === 第一段：上右边线 ===
        let straightLength = (width - height) / 2
        let straightProgress = min(remaining / straightLength, 1)
        let xStart = straightLength + radius
        let xEnd = (width - height) / 2 - straightProgress * (width - height) / 2
        path.move(to: CGPoint(x: xStart, y: 0))
        path.addLine(to: CGPoint(x: width - radius - xEnd, y: 0))
        path.closeSubpath()
        remaining -= straightLength * straightProgress
        
        // === 第二段：右半圆弧 ===
        if remaining > 0 {
            let startAngle = -90.0
            let arcLength = .pi * radius
            let arcProgress = min(remaining / arcLength, 1)
            let endAngle = startAngle + 180 * arcProgress
            path.addArc(center: CGPoint(x: width - radius, y: height / 2),
                        radius: radius,
                        startAngle: .degrees(startAngle),
                        endAngle: .degrees(endAngle),
                        clockwise: false)
            //path.closeSubpath()
            remaining -= arcLength * arcProgress
        }

        // === 第三段：下边线 ===
        if remaining > 0 {
            let straightLength = width - height
            let straightProgress = min(remaining / straightLength, 1)
            //let xStart = width - height
            let xEnd = width - height - (width - height) * straightProgress
            path.move(to: CGPoint(x: width - radius, y: height))
            path.addLine(to: CGPoint(x: xEnd + radius, y: height))
            path.closeSubpath()
            remaining -= straightLength * straightProgress
        }

        // === 第四段：左半圆弧 ===
        if remaining > 0 {
            let arcLength = .pi * radius
            let arcProgress = min(remaining / arcLength, 1)
            let startAngle = 90.0
            let endAngle = startAngle + 180 * arcProgress
            path.addArc(center: CGPoint(x: radius, y: height / 2),
                        radius: radius,
                        startAngle: .degrees(startAngle),
                        endAngle: .degrees(endAngle),
                        clockwise: false)
            //path.closeSubpath()
            remaining -= arcLength * arcProgress
        }

        // === 第五段：上左边线 ===
        if remaining > 0 {
            let straightLength = width - height
            let straightProgress = min(remaining / straightLength, 1)
            let xStart = radius
            let xEnd = radius + (width - height) * straightProgress
            path.move(to: CGPoint(x: xStart, y: 0))
            path.addLine(to: CGPoint(x: xEnd, y: 0))
            path.closeSubpath()
        }

        return path
    }

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
}
