//
//  WeeklyTrainingChartView.swift
//  sportsx
//
//  训练模块周折线图：7 个等宽可点击区域，折线 + 数据点，选中区高亮，底部星期标签。
//  纯 SwiftUI 自绘（Path），对齐项目 MiniTrackView/ProgressBar 风格；含 0 基线，兼容负值（momentum 变化量）。
//

import SwiftUI


struct WeeklyTrainingChartView: View {
    let values: [Double]          // 7 个值（顺序：旧→新）
    let labels: [String]          // 7 个星期短标签
    @Binding var selectedIndex: Int
    var lineColor: Color = .orange

    private let labelHeight: CGFloat = 20
    private let topPadding: CGFloat = 8
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

            // 数据点
            ForEach(values.indices, id: \.self) { i in
                Circle()
                    .fill(i == selectedIndex ? lineColor : lineColor.opacity(0.6))
                    .frame(width: i == selectedIndex ? 9 : 6, height: i == selectedIndex ? 9 : 6)
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
