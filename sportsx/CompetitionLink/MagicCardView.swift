//
//  MagicCardView.swift
//  sportsx
//
//  Created by 任杰 on 2024/12/26.
//

import SwiftUI



// MARK: - 卡牌视图
struct CardView: View {
    let card: MagicCard
    @State private var showDetail: Bool = false
    var showDetailButton: Bool = true
    
    // 定义布局比例常量
    private let cornerRadiusRatio: CGFloat = 0.08     // 卡牌圆角占宽度的比例
    private let strokeWidthRatio: CGFloat = 0.015     // 边框宽度占宽度的比例
    private let imageHeightRatio: CGFloat = 0.55      // 图片高度占总高度的比例
    private let imageWidthRatio: CGFloat = 0.8        // 图片宽度占总宽度的比例
    private let imageCornerRadiusRatio: CGFloat = 0.06 // 图片圆角占宽度的比例
    private let textEnergyOffset: CGFloat = 0.05      // 能量文本占高度的比例
    private let nameFontSizeRatio: CGFloat = 0.085    // 名称字体大小占宽度的比例
    private let infoFontSizeRatio: CGFloat = 0.07     // 信息字体大小占宽度的比例
    private let verticalSpacingRatio: CGFloat = 0.02  // 垂直间距占高度的比例
    
    var body: some View {
        cardContent
            .fullScreenCover(isPresented: $showDetail) {
                CardDetailView(card: card, isPresented: $showDetail)
            }
    }
    
    // 提取卡牌内容为独立视图
    private var cardContent: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            // 计算各元素尺寸
            let cornerRadius = width * cornerRadiusRatio
            let strokeWidth = width * strokeWidthRatio
            let imageHeight = height * imageHeightRatio
            let imageWidth = width * imageWidthRatio
            let imageCornerRadius = width * imageCornerRadiusRatio
            let energyOffset = height * textEnergyOffset
            let nameFont = Font.system(size: width * nameFontSizeRatio, weight: .semibold)
            let infoFont = Font.system(size: width * infoFontSizeRatio, weight: .medium)
            let verticalSpacing = height * verticalSpacingRatio
            let statsFontSize = width * 0.065
            
            ZStack {
                // 卡牌背景
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                gradeColor(for: card.grade).opacity(0.2),
                                gradeColor(for: card.grade).opacity(0.4)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [.white.opacity(0.7), gradeColor(for: card.grade)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: strokeWidth
                            )
                    )
                    .shadow(color: gradeColor(for: card.grade).opacity(0.4), radius: cornerRadius/3, x: 0, y: cornerRadius/6)
                
                VStack(spacing: verticalSpacing) {
                    // grade、能量条和等级
                    HStack(spacing: width * 0.03) {
                        // Grade标签
                        Text(card.grade)
                            .font(.system(size: statsFontSize, weight: .bold))
                            .padding(.horizontal, width * 0.03)
                            .padding(.vertical, width * 0.01)
                            .foregroundColor(.white)
                            .background(gradeColor(for: card.grade))
                            .cornerRadius(width * 0.03)
                        
                        // 能量条
                        ZStack(alignment: .leading) {
                            // 背景条
                            RoundedRectangle(cornerRadius: width * 0.02)
                                .frame(height: height * 0.025)
                                .foregroundColor(Color.gray.opacity(0.3))
                            
                            // 能量值填充
                            RoundedRectangle(cornerRadius: width * 0.02)
                                .frame(width: max(width * 0.5 * CGFloat(card.energy) / 100.0, width * 0.02), height: height * 0.025)
                                .foregroundColor(energyColor(percentage: card.energy))
                            
                            // 能量值文本
                            HStack {
                                HStack(spacing: width * 0.01) {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: statsFontSize * 0.7))
                                        .foregroundColor(energyColor(percentage: card.energy))
                                    
                                    Text("\(card.energy)")
                                        .font(.system(size: statsFontSize * 0.8, weight: .bold))
                                        .foregroundColor(energyColor(percentage: card.energy))
                                }
                                .padding(.horizontal, width * 0.02)
                            }
                            .frame(width: width * 0.5)
                            .offset(y: -energyOffset)
                        }
                        .frame(width: width * 0.5)
                        
                        // 等级
                        Text("Lv.\(card.level)")
                            .font(.system(size: statsFontSize, weight: .medium))
                            .foregroundColor(.primary.opacity(0.7))
                    }
                    .frame(width: width * 0.9)
                    
                    // 卡牌图像
                    Image(card.imageURL)
                        .resizable()
                        .scaledToFit()
                        .frame(width: imageWidth, height: imageHeight)
                        .clipShape(RoundedRectangle(cornerRadius: imageCornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: imageCornerRadius)
                                .stroke(Color.white.opacity(0.6), lineWidth: strokeWidth/2)
                        )
                        .shadow(color: .black.opacity(0.2), radius: imageCornerRadius/4, x: 0, y: imageCornerRadius/8)
                    
                    // 卡牌名称
                    Text(card.name)
                        .font(nameFont)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    // 卡牌信息
                    HStack(spacing: width * 0.01) {
                        Text("·")
                            .font(infoFont)
                            .foregroundColor(.secondary)
                        
                        Text(card.type)
                            .font(infoFont)
                            .foregroundColor(colorForType(card.type))
                    }
                }
                
                // 右下角的详情按钮 (根据需要显示)
                if showDetailButton {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                showDetail = true
                            }) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: width * 0.12))
                                    .foregroundColor(.white.opacity(0.8))
                                    .shadow(color: .black.opacity(0.5), radius: 1)
                                    .padding(width * 0.04)
                            }
                        }
                    }
                }
            }
        }
        .aspectRatio(5/7, contentMode: .fit)
    }
    
    // 根据卡牌类型返回对应的颜色
    private func colorForType(_ type: String) -> Color {
        switch type.lowercased() {
        case "dragon":
            return .red
        case "serpent":
            return .blue
        case "golem":
            return .brown
        case "phoenix":
            return .orange
        case "tiger":
            return .yellow
        default:
            return .purple
        }
    }
    
    // 根据Grade返回对应的颜色
    private func gradeColor(for grade: String) -> Color {
        let firstChar = grade.first ?? "C"
        
        switch firstChar {
        case "S":
            return Color.yellow
        case "A":
            return Color.green
        case "B":
            return Color.blue
        case "C":
            return Color.purple
        case "D":
            return Color.gray
        default:
            return Color.gray
        }
    }
    
    // 根据能量百分比返回对应的颜色
    private func energyColor(percentage: Int) -> Color {
        if percentage > 75 {
            return Color.green
        } else if percentage > 50 {
            return Color.yellow
        } else if percentage > 25 {
            return Color.orange
        } else {
            return Color.red
        }
    }
}

// MARK: - 空卡牌槽位
struct EmptyCardSlot: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let iconSize = width * 0.3
            let fontSize = width * 0.085
            
            ZStack {
                RoundedRectangle(cornerRadius: width * 0.08)
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: width * 0.08)
                            .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: width * 0.015, dash: [width * 0.05]))
                    )
                
                VStack(spacing: width * 0.05) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: iconSize))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("空卡牌槽")
                        .font(.system(size: fontSize))
                        .foregroundColor(.gray.opacity(0.7))
                }
            }
        }
        .aspectRatio(5/7, contentMode: .fit)
    }
}

// MARK: - 可选择卡牌视图
struct CardSelectableView: View {
    let card: MagicCard
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        ZStack {
            // 卡牌视图
            CardView(card: card)
                .overlay(
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: geometry.size.width * 0.08)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: geometry.size.width * 0.015)
                    }
                )
            
            // 选中蒙版
            if isSelected {
                GeometryReader { geometry in
                    ZStack {
                        Color.black.opacity(0.3)
                            .cornerRadius(geometry.size.width * 0.08)
                        
                        Text("已装备")
                            .font(.system(size: geometry.size.width * 0.2, weight: .bold))
                            .foregroundColor(.white)
                            .padding(geometry.size.width * 0.04)
                            .background(Color.green.opacity(0.5))
                            .cornerRadius(geometry.size.width * 0.04)
                    }
                }
            }
        }
        .aspectRatio(5/7, contentMode: .fit)
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - 卡牌详情视图
struct CardDetailView: View {
    let card: MagicCard
    @Binding var isPresented: Bool
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            // 背景颜色
            Color(UIColor.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 15) {
                // 顶部关闭按钮
                HStack {
                    Text("卡牌详情")
                        .font(.title3)
                        .bold()
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        isPresented = false
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding([.horizontal, .top])
                
                // 卡牌展示
                CardView(card: card, showDetailButton: false)
                    .frame(height: 240)
                    .padding()
                
                ScrollView {
                    // 卡牌详细数据
                    VStack(spacing: 15) {
                        // 卡牌幸运值
                        HStack {
                            Text("幸运值")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(Int(card.lucky)) %")
                                .font(.headline)
                                .foregroundColor(luckyColor(percentage: Float(card.lucky)))
                            
                            Image(systemName: luckySymbol(percentage: Float(card.lucky)))
                                .foregroundColor(luckyColor(percentage: Float(card.lucky)))
                        }
                        .padding(.horizontal)
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // 卡牌描述
                        VStack(alignment: .leading, spacing: 8) {
                            Text("卡牌描述")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text(card.description)
                                .font(.body)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        
                        // 传感器要求（如果有）
                        if card.sensorLocation != 0 {
                            Divider()
                                .padding(.horizontal)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("传感器要求")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 15) {
                                        if (card.sensorLocation & 0b100000) != 0 {
                                            sensorIcon(name: "iphone", text: "手机")
                                        }
                                        if (card.sensorLocation & 0b010000) != 0 {
                                            sensorIcon(name: "hand.raised.fill", text: "左手")
                                        }
                                        if (card.sensorLocation & 0b001000) != 0 {
                                            sensorIcon(name: "hand.point.right.fill", text: "右手")
                                        }
                                        if (card.sensorLocation & 0b000100) != 0 {
                                            sensorIcon(name: "figure.walk", text: "左脚")
                                        }
                                        if (card.sensorLocation & 0b000010) != 0 {
                                            sensorIcon(name: "figure.walk", text: "右脚")
                                        }
                                        if (card.sensorLocation & 0b000001) != 0 {
                                            sensorIcon(name: "waveform.path.ecg", text: "腰部")
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 20)
                    }
                }
            }
            .padding(.bottom)
        }
        .presentationDetents([.medium, .large])
    }
    
    // 传感器图标视图
    private func sensorIcon(name: String, text: String) -> some View {
        VStack {
            Image(systemName: name)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 50, height: 50)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
    
    // 根据幸运值返回对应的颜色
    private func luckyColor(percentage: Float) -> Color {
        if percentage > 90 {
            return .green
        } else if percentage > 70 {
            return .blue
        } else if percentage > 50 {
            return .yellow
        } else if percentage > 30 {
            return .orange
        } else {
            return .red
        }
    }
    
    // 根据幸运值返回对应的符号
    private func luckySymbol(percentage: Float) -> String {
        if percentage > 90 {
            return "star.fill"
        } else if percentage > 70 {
            return "star.leadinghalf.filled"
        } else if percentage > 50 {
            return "star"
        } else if percentage > 30 {
            return "exclamationmark.triangle"
        } else {
            return "exclamationmark.triangle.fill"
        }
    }
}

