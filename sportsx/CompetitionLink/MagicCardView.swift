//
//  MagicCardView.swift
//  sportsx
//
//  Created by 任杰 on 2024/12/26.
//

import SwiftUI



// MARK: - 卡牌视图
struct MagicCardView: View {
    let card: MagicCard
    @State private var showDetail: Bool = false
    let showDetailButton: Bool
    
    init(card: MagicCard, showDetailButton: Bool = true) {
        self.card = card
        self.showDetailButton = showDetailButton
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            let cornerRadius = width * 0.08
            let strokeWidth = width * 0.03
            let nameFont = Font.system(size: width * 0.12, weight: .semibold)
            let statsFont = Font.system(size: width * 0.1, weight: .medium)
            
            ZStack {
                // 背景图
                CachedAsyncImage(
                    urlString: card.imageURL,
                    placeholder: Image("Ads"),
                    errorImage: Image(systemName: "photo.badge.exclamationmark")
                )
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()
                
                VStack(spacing: 0) {
                    HStack {
                        Text(card.rarity)
                            .padding(.horizontal, width * 0.03)
                            .padding(.vertical, width * 0.01)
                            .background(gradeColor(for: card.rarity))
                            .cornerRadius(width * 0.03)
                        
                        Spacer()
                        
                        Image(systemName: card.sportType.iconName)
                        
                        Spacer()
                        
                        Text("Lv.\(card.level)")
                            .opacity(card.level > 0 ? 1 : 0)
                    }
                    .font(statsFont.weight(.bold))
                    .frame(width: width * 0.9)
                    .padding(.top, height * 0.04)
                    
                    Spacer()
                    
                    Text(card.name)
                        .font(nameFont)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(width * 0.05)
                        .background(Color.gray)
                        .cornerRadius(width * 0.03)
                        .padding(.bottom, height * 0.07)
                }
                .foregroundColor(.white)
                
                if showDetailButton {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                showDetail = true
                            } label: {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: width * 0.15))
                                    .foregroundColor(.white.opacity(0.8))
                                    .shadow(color: .black.opacity(0.5), radius: 1)
                            }
                            .padding(width * 0.05)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [gradeColor(for: card.rarity), gradeColor(for: card.rarity).opacity(0.3)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: strokeWidth
                    )
            )
        }
        .aspectRatio(5/7, contentMode: .fit) // 保持卡牌比例
        .fullScreenCover(isPresented: $showDetail) {
            CardDetailView(card: card, isPresented: $showDetail)
        }
    }
    
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
        default:
            return Color.gray
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
struct MagicCardSelectableView: View {
    let card: MagicCard
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        ZStack {
            // 卡牌视图
            MagicCardView(card: card)
                .overlay(
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: geometry.size.width * 0.08)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: geometry.size.width * 0.02)
                    }
                )
            
            if !checkForValid() {
                GeometryReader { geometry in
                    ZStack {
                        Color.black.opacity(0.3)
                            .cornerRadius(geometry.size.width * 0.08)
                        
                        Text("不可用")
                            .font(.system(size: geometry.size.width * 0.2, weight: .bold))
                            .foregroundColor(.white)
                            .padding(geometry.size.width * 0.04)
                            .background(Color.red.opacity(0.5))
                            .cornerRadius(geometry.size.width * 0.04)
                    }
                }
            }
            
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
        //.aspectRatio(5/7, contentMode: .fit)
        .onTapGesture {
            guard checkForValid() else {
                return
            }
            onTap()
        }
    }
    
    func checkForValid() -> Bool {
        // 检查运动类型
        guard card.sportType == CompetitionManager.shared.sport else { return false }
        // 检查组队模式
        if card.tags.first(where: { $0 == "team" }) != nil {
            guard CompetitionManager.shared.isTeam else { return false }
        }
        // 检查传感器
        if let location = card.sensorLocation {
            guard DeviceManager.shared.checkSensorLocation(at: location >> 1, in: card.sensorType) else { return false }
        }
        // 检查版本
        guard AppVersionManager.shared.checkMinimumVersion(card.version) else { return false }
        return true
    }
}

// MARK: - 卡牌详情视图
struct CardDetailView: View {
    let card: MagicCard
    @Binding var isPresented: Bool
    
    var body: some View {
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
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            
            // 卡牌展示
            MagicCardView(card: card, showDetailButton: false)
            
            ScrollView {
                // 卡牌详细数据
                VStack(alignment: .leading, spacing: 15) {
                    // 卡牌幸运值
                    if card.lucky > 0 {
                        HStack {
                            Text("幸运值")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(String(format: "%0.2f", card.lucky))
                                .font(.headline)
                                .foregroundColor(luckyColor(percentage: Float(card.lucky)))
                            
                            Image(systemName: luckySymbol(percentage: Float(card.lucky)))
                                .foregroundColor(luckyColor(percentage: Float(card.lucky)))
                        }
                        .padding(.top, 10)
                    }
                    
                    Divider()
                    
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
                    
                    // 传感器要求（如果有）
                    if !card.sensorType.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("传感器类型")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 15) {
                                    ForEach (card.sensorType, id: \.self) { sensor in
                                        sensorIcon(name: sensor.iconName, text: sensor.displayName)
                                    }
                                }
                            }
                        }
                    }
                    
                    if let location = card.sensorLocation {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("传感器位置")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 15) {
                                    if (location & 0b000001) != 0 {
                                        sensorIcon(name: "iphone", text: "手机")
                                    }
                                    if (location & 0b000010) != 0 {
                                        sensorIcon(name: "hand.raised.fill", text: "左手")
                                    }
                                    if (location & 0b000100) != 0 {
                                        sensorIcon(name: "hand.point.right.fill", text: "右手")
                                    }
                                    if (location & 0b001000) != 0 {
                                        sensorIcon(name: "figure.walk", text: "左脚")
                                    }
                                    if (location & 0b010000) != 0 {
                                        sensorIcon(name: "figure.walk", text: "右脚")
                                    }
                                    if (location & 0b100000) != 0 {
                                        sensorIcon(name: "waveform.path.ecg", text: "腰部")
                                    }
                                }
                            }
                        }
                    }
                    // todo: 添加Skill1/2/3的显示区域，区域展示description和对应level，level以点亮5个小方形矩形的方式展示
                    // 技能展示
                    Divider()
                    VStack(alignment: .leading, spacing: 15) {
                        if let des = card.descriptionSkill1 {
                            skillSection(
                                title: "技能1",
                                unlockLevel: 3,
                                currentLevel: card.levelSkill1,
                                cardLevel: card.level,
                                description: des
                            )
                        }
                        if let des = card.descriptionSkill2 {
                            skillSection(
                                title: "技能2",
                                unlockLevel: 6,
                                currentLevel: card.levelSkill2,
                                cardLevel: card.level,
                                description: des
                            )
                        }
                        if let des = card.descriptionSkill3 {
                            skillSection(
                                title: "技能3",
                                unlockLevel: 10,
                                currentLevel: card.levelSkill3,
                                cardLevel: card.level,
                                description: des
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    private func skillSection(
        title: String,
        unlockLevel: Int,
        currentLevel: Int?,
        cardLevel: Int,
        description: String
    ) -> some View {
        let isUnlocked = cardLevel >= unlockLevel
        
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(title)")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("（Lv.\(unlockLevel)解锁）")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .opacity(isUnlocked ? 0 : 1)
                
                Spacer()
                
                // 等级方块
                if let currentLevel = currentLevel {
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { i in
                            Rectangle()
                                .fill(i < currentLevel && isUnlocked ? Color.orange : Color.gray.opacity(0.3))
                                .frame(width: 12, height: 12)
                                .cornerRadius(2)
                        }
                    }
                }
            }
            
            Text(description)
                .font(.subheadline)
                .foregroundColor((isUnlocked || (currentLevel == nil)) ? .primary : .gray)
                .fixedSize(horizontal: false, vertical: true)
        }
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

/*#Preview() {
    let card = MagicCard(cardID: "qwe", name: "踏频仙人", sportType: .Bike, level: 5, levelSkill1: 2, levelSkill2: 3, levelSkill3: nil, imageURL: "Ads", sensorType: .heartSensor, sensorLocation: 7, lucky: 67.3, rarity: "A", description: "这是一段描述", descriptionSkill1: "技能1的描述", descriptionSkill2: "技能2的描述", descriptionSkill3: nil, version: AppVersion("1.0.0"), tags: [], effectDef: MagicCardDef(cardID: "qwe", typeName: "pedal", params: .string("")))
    MagicCardView(card: card)
}*/
