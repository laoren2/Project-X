//
//  WeeklyTrainingChartView.swift
//  sportsx
//
//  训练模块周折线图：7 个等宽可点击区域，折线 + 数据点（未选空心圈、选中实心放大）、
//  每个数据点上方显示数值，选中区高亮，底部星期标签。
//  纯 SwiftUI 自绘（Path），对齐项目 MiniTrackView/ProgressBar 风格；含 0 基线，兼容负值（momentum 变化量）。
//

import SwiftUI


struct WeeklyTrainingChartView: View {
    let userManager = UserManager.shared
    let values: [Double]          // 7 个值（顺序：旧→新）
    let valueLabels: [String]     // 7 个数值文案（由调用方按指标格式化）
    let labels: [String]          // 7 个星期短标签
    @Binding var selectedIndex: Int
    var lineColor: Color = .orange
    //var pointBackground: Color = Color.defaultBackground   // 空心圈内部填充色，用于遮挡其下方折线

    private let labelHeight: CGFloat = 20
    private let topPadding: CGFloat = 24      // 顶部留白容纳数据点上方的数值
    private let bottomPadding: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            chartContent(in: geo.size)
        }
    }

    private func point(_ i: Int, size: CGSize) -> CGPoint {
        let n = max(values.count, 1)
        let colW = size.width / CGFloat(n)
        let chartH = max(size.height - labelHeight, 1)
        let yMin = min(0, values.min() ?? 0)
        let yMax = max(0, values.max() ?? 0)
        let span = max(yMax - yMin, 1e-9)

        let x = colW * (CGFloat(i) + 0.5)
        let norm = (values[i] - yMin) / span
        let usableH = chartH - topPadding - bottomPadding
        let y = topPadding + (1 - CGFloat(norm)) * usableH
        return CGPoint(x: x, y: y)
    }

    private func chartContent(in size: CGSize) -> some View {
        let n = max(values.count, 1)
        let colW = size.width / CGFloat(n)
        let chartH = max(size.height - labelHeight, 1)

        return ZStack(alignment: .topLeading) {
            // 选中区高亮
            if values.indices.contains(selectedIndex) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(lineColor.opacity(0.15))
                    .frame(width: max(colW - 8, 1), height: chartH)
                    .position(x: colW * (CGFloat(selectedIndex) + 0.5), y: chartH / 2)
            }

            // 折线
            if values.count >= 2 {
                Path { p in
                    for i in values.indices {
                        let q = point(i, size: size)
                        if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
                    }
                }
                .stroke(lineColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }

            // 数据点上方数值
            ForEach(values.indices, id: \.self) { i in
                let pt = point(i, size: size)
                let isSel = i == selectedIndex
                Text(valueLabels.indices.contains(i) ? valueLabels[i] : "")
                    .font(.system(size: 12, weight: isSel ? .bold : .regular))
                    .foregroundStyle(isSel ? Color.white : Color.secondText)
                    .fixedSize()
                    .position(x: pt.x, y: max(pt.y - 16, 9))
            }

            // 数据点：未选空心圈（内部填背景色遮挡折线）、选中实心并放大
            ForEach(values.indices, id: \.self) { i in
                let isSel = i == selectedIndex
                Group {
                    if isSel {
                        Circle().fill(lineColor)
                            .frame(width: 16, height: 16)
                    } else {
                        Circle()
                            .fill(userManager.backgroundColor.softenColor(blendWithWhiteRatio: 0.1))
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(lineColor, lineWidth: 2))
                    }
                }
                .position(point(i, size: size))
            }

            // 星期标签 + 整列点击区
            HStack(spacing: 0) {
                ForEach(values.indices, id: \.self) { i in
                    VStack(spacing: 0) {
                        Spacer()
                        Text(labels.indices.contains(i) ? labels[i] : "")
                            .font(.system(size: 11, weight: i == selectedIndex ? .bold : .regular))
                            .foregroundStyle(i == selectedIndex ? Color.white : Color.secondText)
                            .frame(height: labelHeight)
                    }
                    .frame(width: colW, height: size.height)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedIndex = i
                    }
                }
            }
        }
    }
}
