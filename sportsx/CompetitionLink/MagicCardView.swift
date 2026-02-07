//
//  MagicCardView.swift
//  sportsx
//
//  Created by 任杰 on 2024/12/26.
//

import SwiftUI



// MARK: - 卡牌视图
struct MagicCardView: View {
    @ObservedObject var navigationManager = NavigationManager.shared
    let card: MagicCard
    let showDetailButton: Bool
    let isShopCardView: Bool
    
    init(card: MagicCard, showDetailButton: Bool = true, isShopCardView: Bool = false) {
        self.card = card
        self.showDetailButton = showDetailButton
        self.isShopCardView = isShopCardView
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            let cornerRadius = width * 0.08
            let strokeWidth = width * 0.02
            let nameFont = Font.system(size: width * 0.13, weight: .bold)
            
            ZStack {
                // 背景图
                CachedAsyncImage(
                    urlString: card.imageURL
                )
                .id(card.imageURL)
                .scaledToFill()
                .frame(width: width, height: height)
                
                // 卡牌信息
                VStack(spacing: 0) {
                    Rectangle()
                        .foregroundStyle(gradeColor(for: card.rarity))
                        .frame(height: height * 0.03)
                    HStack {
                        Image(card.sportType.iconName)
                            .resizable()
                            .scaledToFit()
                            .frame(height: width * 0.15)
                        
                        Spacer()
                        Text("\(card.level.roman)")
                            .font(Font.system(size: width * 0.15, weight: .bold))
                            .opacity(card.level > 0 ? 1 : 0)
                    }
                    .padding(.horizontal, width * 0.05)
                    .padding(.top, height * 0.02)
                    .background(
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.black.opacity(0.7),
                                        Color.black.opacity(0)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    Spacer()
                    HStack {
                        Text(card.name)
                            .font(nameFont)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .minimumScaleFactor(0.7)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, width * 0.05)
                    .padding(.bottom, width * 0.02)
                    .background(
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.black.opacity(0.7),
                                        Color.black.opacity(0)
                                    ]),
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                    )
                    Rectangle()
                        .foregroundStyle(gradeColor(for: card.rarity))
                        .frame(height: height * 0.08)
                }
                .foregroundColor(.white)
                
                if showDetailButton {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                if isShopCardView {
                                    navigationManager.append(.shopCardDetailView(defID: card.defID))
                                } else {
                                    navigationManager.append(.userCardDetailView(cardID: card.cardID))
                                }
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
            .contentShape(Rectangle())
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.white.opacity(0.4),
                                Color.clear
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: strokeWidth
                    )
                    .blendMode(.screen)
            )
        }
        .aspectRatio(5/7, contentMode: .fit) // 保持卡牌比例
    }
    
    private func gradeColor(for grade: String) -> LinearGradient {
        let firstChar = grade.first ?? "C"
        
        switch firstChar {
        case "S":
            return Color.specialCard
        case "A":
            return Color.gold
        case "B":
            return Color.silver
        case "C":
            return Color.bronze
        default:
            return Color.bronze
        }
    }
}

// MARK: - 空卡牌槽位
struct EmptyCardSlot: View {
    let text: String
    let ratio: Double
    
    init(text: String = "competition.cardselect.magiccard.empty_slot", ratio: Double = 5/7) {
        self.text = text
        self.ratio = ratio
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let iconSize = width * 0.3
            let fontSize = width * 0.085
            
            ZStack {
                RoundedRectangle(cornerRadius: width * 0.08)
                    .fill(Color.gray.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: width * 0.08)
                            .stroke(Color.white.opacity(0.6), style: StrokeStyle(lineWidth: width * 0.015, dash: [width * 0.05]))
                    )
                
                VStack(spacing: width * 0.05) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: iconSize))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text(LocalizedStringKey(text))
                        .font(.system(size: fontSize))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .aspectRatio(ratio, contentMode: .fit)
    }
}

// MARK: - 空VIP卡牌槽位
struct EmptyCardVipSlot: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let iconSize = width * 0.3
            let fontSize = width * 0.085
            
            ZStack {
                RoundedRectangle(cornerRadius: width * 0.08)
                    .fill(Color.orange.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: width * 0.08)
                            .stroke(Color.orange, style: StrokeStyle(lineWidth: width * 0.015, dash: [width * 0.05]))
                    )
                
                VStack(spacing: width * 0.05) {
                    Image("vip_icon_on")
                        .resizable()
                        .scaledToFit()
                        .frame(height: iconSize)
                    Text("competition.cardselect.magiccard.vipslot")
                        .font(.system(size: fontSize))
                        .foregroundColor(.orange)
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
    
    var body: some View {
        ZStack {
            // 卡牌视图
            MagicCardView(card: card)
                .overlay(
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: geometry.size.width * 0.08)
                            .stroke(isSelected ? Color.green : Color.clear, lineWidth: geometry.size.width * 0.02)
                    }
                )
            
            if !checkForValid() {
                GeometryReader { geometry in
                    ZStack {
                        Color.black.opacity(0.3)
                            .cornerRadius(geometry.size.width * 0.08)
                        
                        Text("warehouse.equipcard.unavailable")
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
                        
                        Text("competition.cardselect.magiccard.equipped")
                            .font(.system(size: geometry.size.width * 0.2, weight: .bold))
                            .foregroundColor(.white)
                            .padding(geometry.size.width * 0.04)
                            .background(Color.green.opacity(0.5))
                            .cornerRadius(geometry.size.width * 0.04)
                    }
                }
            }
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
            if !DeviceManager.shared.checkSensorLocation(at: location >> 1, in: card.sensorType) {
                if card.sensorLocation2 == nil {
                    return false
                }
                if let location2 = card.sensorLocation2, !DeviceManager.shared.checkSensorLocation(at: location2 >> 1, in: card.sensorType) {
                    return false
                }
            }
        }
        // 检查版本
        guard AppVersionManager.shared.checkMinimumVersion(card.version) else { return false }
        return true
    }
}

// MARK: - 用户卡牌详情视图
struct UserCardDetailView: View {
    @ObservedObject var navigationManager = NavigationManager.shared
    @State var card: MagicCard?
    @State var backgroundColor: Color = .defaultBackground
    let cardID: String
    
    var body: some View {
        if let card = card {
            ZStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                backgroundColor.softenColor(blendWithWhiteRatio: 0.2),
                                backgroundColor
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .ignoresSafeArea()
                VStack(spacing: 15) {
                    // 顶部关闭按钮
                    HStack {
                        Text("magiccard.detail")
                            .font(.title2)
                            .bold()
                            .foregroundStyle(Color.white)
                        
                        Spacer()
                        
                        Button(action: {
                            navigationManager.removeLast()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(Color.secondText)
                        }
                    }
                    .padding(.horizontal)
                    // 卡牌展示
                    MagicCardView(card: card, showDetailButton: false)
                        .frame(height: 300)
                    
                    ScrollView {
                        // 卡牌详细数据
                        VStack(alignment: .leading, spacing: 15) {
                            // 卡牌幸运值
                            HStack {
                                Text("magiccard.detail.lucky")
                                    .font(.headline)
                                    .foregroundStyle(Color.white)
                                Image(systemName: "info.circle")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondText)
                                    .exclusiveTouchTapGesture {
                                        PopupWindowManager.shared.presentPopup(
                                            title: "magiccard.detail.lucky",
                                            message: "magiccard.detail.lucky.popup",
                                            bottomButtons: [
                                                .confirm()
                                            ]
                                        )
                                    }
                                Spacer()
                                Text(String(format: "%0.2f", card.lucky))
                                    .font(.headline)
                                    .foregroundStyle(Color.secondText)
                            }
                            .padding(.top, 10)
                            
                            Rectangle()
                                .foregroundStyle(Color.thirdText)
                                .frame(height: 1)
                            
                            // 卡牌描述
                            VStack(alignment: .leading, spacing: 8) {
                                Text("magiccard.detail.description")
                                    .font(.headline)
                                    .foregroundStyle(Color.white)
                                
                                Text(card.description)
                                    .font(.body)
                                    .foregroundStyle(Color.secondText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            // 传感器要求（如果有）
                            if !card.sensorType.isEmpty {
                                Rectangle()
                                    .foregroundStyle(Color.thirdText)
                                    .frame(height: 1)
                                
                                VStack(spacing: 8) {
                                    HStack {
                                        Text("magiccard.detail.sensor.type")
                                            .font(.headline)
                                            .foregroundStyle(Color.white)
                                        Image(systemName: "info.circle")
                                            .font(.subheadline)
                                            .foregroundStyle(Color.secondText)
                                            .exclusiveTouchTapGesture {
                                                PopupWindowManager.shared.presentPopup(
                                                    title: "magiccard.detail.sensor.type",
                                                    message: "magiccard.detail.sensor.type.popup",
                                                    bottomButtons: [
                                                        .confirm()
                                                    ]
                                                )
                                            }
                                        Spacer()
                                    }
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 15) {
                                            ForEach (card.sensorType, id: \.self) { sensor in
                                                VStack {
                                                    Image(systemName: sensor.iconName)
                                                        .font(.system(size: 20))
                                                    Text(LocalizedStringKey(sensor.displayName))
                                                        .font(.caption)
                                                }
                                                .padding(.horizontal)
                                                .frame(height: 50)
                                                .foregroundStyle(Color.white)
                                                .background(Color.white.opacity(0.2))
                                                .cornerRadius(8)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            if let location = card.sensorLocation {
                                Rectangle()
                                    .foregroundStyle(Color.thirdText)
                                    .frame(height: 1)
                                
                                VStack(spacing: 8) {
                                    HStack {
                                        Text("magiccard.detail.sensor.pos")
                                            .font(.headline)
                                            .foregroundStyle(Color.white)
                                        Image(systemName: "info.circle")
                                            .font(.subheadline)
                                            .foregroundStyle(Color.secondText)
                                            .exclusiveTouchTapGesture {
                                                PopupWindowManager.shared.presentPopup(
                                                    title: "magiccard.detail.sensor.pos",
                                                    message: "magiccard.detail.sensor.pos.popup",
                                                    bottomButtons: [
                                                        .confirm()
                                                    ]
                                                )
                                            }
                                        Spacer()
                                    }
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack {
                                            HStack(spacing: 15) {
                                                if (location & 0b000001) != 0 {
                                                    sensorIcon(name: "iphone", text: "magiccard.detail.sensor.pos.phone")
                                                }
                                                if (location & 0b000010) != 0 {
                                                    sensorIcon(name: "left_hand", text: "user.page.bind_device.body.lh")
                                                }
                                                if (location & 0b000100) != 0 {
                                                    sensorIcon(name: "right_hand", text: "user.page.bind_device.body.rh")
                                                }
                                                if (location & 0b001000) != 0 {
                                                    sensorIcon(name: "left_foot", text: "user.page.bind_device.body.lf")
                                                }
                                                if (location & 0b010000) != 0 {
                                                    sensorIcon(name: "right_foot", text: "user.page.bind_device.body.rf")
                                                }
                                                if (location & 0b100000) != 0 {
                                                    sensorIcon(name: "chest", text: "user.page.bind_device.body.wst")
                                                }
                                            }
                                            if let location2 = card.sensorLocation2 {
                                                Text("common.or")
                                                    .foregroundStyle(Color.secondText)
                                                HStack(spacing: 15) {
                                                    if (location2 & 0b000001) != 0 {
                                                        sensorIcon(name: "iphone", text: "magiccard.detail.sensor.pos.phone")
                                                    }
                                                    if (location2 & 0b000010) != 0 {
                                                        sensorIcon(name: "left_hand", text: "user.page.bind_device.body.lh")
                                                    }
                                                    if (location2 & 0b000100) != 0 {
                                                        sensorIcon(name: "right_hand", text: "user.page.bind_device.body.rh")
                                                    }
                                                    if (location2 & 0b001000) != 0 {
                                                        sensorIcon(name: "left_foot", text: "user.page.bind_device.body.lf")
                                                    }
                                                    if (location2 & 0b010000) != 0 {
                                                        sensorIcon(name: "right_foot", text: "user.page.bind_device.body.rf")
                                                    }
                                                    if (location2 & 0b100000) != 0 {
                                                        sensorIcon(name: "chest", text: "user.page.bind_device.body.wst")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            // 技能展示
                            Rectangle()
                                .foregroundStyle(Color.thirdText)
                                .frame(height: 1)
                            VStack(alignment: .leading, spacing: 15) {
                                if let des = card.descriptionSkill1 {
                                    skillSection(
                                        skillLevel: 1,
                                        unlockLevel: 3,
                                        currentLevel: card.levelSkill1,
                                        cardLevel: card.level,
                                        description: des
                                    )
                                }
                                if let des = card.descriptionSkill2 {
                                    skillSection(
                                        skillLevel: 2,
                                        unlockLevel: 6,
                                        currentLevel: card.levelSkill2,
                                        cardLevel: card.level,
                                        description: des
                                    )
                                }
                                if let des = card.descriptionSkill3 {
                                    skillSection(
                                        skillLevel: 3,
                                        unlockLevel: 10,
                                        currentLevel: card.levelSkill3,
                                        cardLevel: card.level,
                                        description: des
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .enableSwipeBackGesture()
        } else {
            VStack(spacing: 50) {
                VStack(spacing: 20) {
                    HStack(spacing: 20) {
                        Rectangle()
                            .frame(height: 32)
                            .foregroundStyle(Color.gray.opacity(0.5))
                            .cornerRadius(16)
                        Image(systemName: "xmark")
                            .fontWeight(.semibold)
                            .frame(width: 20, height: 20)
                            .foregroundColor(.thirdText)
                            .padding(6)
                            .background(Color.gray.opacity(0.5))
                            .clipShape(Circle())
                            .exclusiveTouchTapGesture {
                                navigationManager.removeLast()
                            }
                    }
                    Rectangle()
                        .aspectRatio(5/7, contentMode: .fit)
                        .frame(height: 300)
                        .foregroundStyle(Color.gray.opacity(0.5))
                        .cornerRadius(20)
                }
                .padding(.horizontal)
                Rectangle()
                    .foregroundStyle(Color.gray.opacity(0.3))
            }
            .toolbar(.hidden, for: .navigationBar)
            .enableSwipeBackGesture()
            .ignoresSafeArea(edges: .bottom)
            .background(Color.defaultBackground)
            .onFirstAppear {
                queryCardInfo()
            }
        }
    }
    
    func queryCardInfo() {
        guard var components = URLComponents(string: "/asset/query_user_equip_card_detail") else { return }
        components.queryItems = [
            URLQueryItem(name: "card_id", value: cardID)
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: MagicCardUserDTO.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        card = MagicCard(from: unwrappedData)
                    }
                    downloadImages(url: unwrappedData.image_url)
                }
            default: break
            }
        }
    }
    
    func downloadImages(url: String) {
        NetworkService.downloadImage(from: url) { image in
            if let image = image {
                if let avg = ImageTool.averageColor(from: image) {
                    DispatchQueue.main.async {
                        self.backgroundColor = avg.bestSoftDarkReadableColor()
                    }
                }
            }
        }
    }
    
    //@ViewBuilder
    private func skillSection(
        skillLevel: Int,
        unlockLevel: Int,
        currentLevel: Int?,
        cardLevel: Int,
        description: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            let isUnlocked = cardLevel >= unlockLevel
            HStack {
                Text("institute.upgrade.skill \(skillLevel)")
                    .font(.headline)
                    .foregroundStyle(Color.white)
                (Text("（level \(unlockLevel.roman) ") + Text("magiccard.detail.skill.unlock") + Text("）"))
                    .font(.subheadline)
                    .foregroundStyle(Color.gray)
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
                .foregroundStyle((isUnlocked || (currentLevel == nil)) ? Color.secondText : Color.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // 传感器图标视图
    private func sensorIcon(name: String, text: String) -> some View {
        VStack(spacing: 2) {
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: 25)
            Text(LocalizedStringKey(text))
                .font(.caption)
                .foregroundStyle(Color.white)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.2))
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

struct ShopCardDetailView: View {
    @ObservedObject var navigationManager = NavigationManager.shared
    @State var card: MagicCardShop?
    @State var backgroundColor: Color = .defaultBackground
    let defID: String
    
    var body: some View {
        if let card = card {
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                backgroundColor.softenColor(blendWithWhiteRatio: 0.2),
                                backgroundColor
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .ignoresSafeArea()
                VStack(spacing: 15) {
                    // 顶部关闭按钮
                    HStack {
                        Text("magiccard.detail")
                            .font(.title2)
                            .bold()
                            .foregroundStyle(Color.white)
                        
                        Spacer()
                        
                        Button(action: {
                            navigationManager.removeLast()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(Color.secondText)
                        }
                    }
                    .padding(.horizontal)
                    // 卡牌展示
                    MagicCardView(card: MagicCard(withShopCard: card), showDetailButton: false)
                        .frame(height: 300)
                    ScrollView {
                        // 卡牌详细数据
                        VStack(alignment: .leading, spacing: 15) {
                            // 卡牌描述
                            VStack(alignment: .leading, spacing: 8) {
                                Text("magiccard.detail.description")
                                    .font(.headline)
                                    .foregroundStyle(Color.white)
                                
                                Text(card.description)
                                    .font(.body)
                                    .foregroundStyle(Color.secondText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            // 传感器要求（如果有）
                            if !card.sensorType.isEmpty {
                                Rectangle()
                                    .foregroundStyle(Color.thirdText)
                                    .frame(height: 1)
                                
                                VStack(spacing: 8) {
                                    HStack {
                                        Text("magiccard.detail.sensor.type")
                                            .font(.headline)
                                            .foregroundStyle(Color.white)
                                        Image(systemName: "info.circle")
                                            .font(.subheadline)
                                            .foregroundStyle(Color.secondText)
                                            .exclusiveTouchTapGesture {
                                                PopupWindowManager.shared.presentPopup(
                                                    title: "magiccard.detail.sensor.type",
                                                    message: "magiccard.detail.sensor.type.popup",
                                                    bottomButtons: [
                                                        .confirm()
                                                    ]
                                                )
                                            }
                                        Spacer()
                                    }
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 15) {
                                            ForEach (card.sensorType, id: \.self) { sensor in
                                                VStack {
                                                    Image(systemName: sensor.iconName)
                                                        .font(.system(size: 20))
                                                    Text(LocalizedStringKey(sensor.displayName))
                                                        .font(.caption)
                                                }
                                                .padding(.horizontal)
                                                .frame(height: 50)
                                                .foregroundStyle(Color.white)
                                                .background(Color.white.opacity(0.2))
                                                .cornerRadius(8)
                                            }
                                        }
                                    }
                                }
                            }
                            if let location = card.sensorLocation {
                                Rectangle()
                                    .foregroundStyle(Color.thirdText)
                                    .frame(height: 1)
                                
                                VStack(spacing: 8) {
                                    HStack {
                                        Text("magiccard.detail.sensor.pos")
                                            .font(.headline)
                                            .foregroundStyle(Color.white)
                                        Image(systemName: "info.circle")
                                            .font(.subheadline)
                                            .foregroundStyle(Color.secondText)
                                            .exclusiveTouchTapGesture {
                                                PopupWindowManager.shared.presentPopup(
                                                    title: "magiccard.detail.sensor.pos",
                                                    message: "magiccard.detail.sensor.pos.popup",
                                                    bottomButtons: [
                                                        .confirm()
                                                    ]
                                                )
                                            }
                                        Spacer()
                                    }
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack {
                                            HStack(spacing: 15) {
                                                if (location & 0b000001) != 0 {
                                                    sensorIcon(name: "iphone", text: "magiccard.detail.sensor.pos.phone")
                                                }
                                                if (location & 0b000010) != 0 {
                                                    sensorIcon(name: "left_hand", text: "user.page.bind_device.body.lh")
                                                }
                                                if (location & 0b000100) != 0 {
                                                    sensorIcon(name: "right_hand", text: "user.page.bind_device.body.rh")
                                                }
                                                if (location & 0b001000) != 0 {
                                                    sensorIcon(name: "left_foot", text: "user.page.bind_device.body.lf")
                                                }
                                                if (location & 0b010000) != 0 {
                                                    sensorIcon(name: "right_foot", text: "user.page.bind_device.body.rf")
                                                }
                                                if (location & 0b100000) != 0 {
                                                    sensorIcon(name: "chest", text: "user.page.bind_device.body.wst")
                                                }
                                            }
                                            if let location2 = card.sensorLocation2 {
                                                Text("common.or")
                                                    .foregroundStyle(Color.secondText)
                                                HStack(spacing: 15) {
                                                    if (location2 & 0b000001) != 0 {
                                                        sensorIcon(name: "iphone", text: "magiccard.detail.sensor.pos.phone")
                                                    }
                                                    if (location2 & 0b000010) != 0 {
                                                        sensorIcon(name: "left_hand", text: "user.page.bind_device.body.lh")
                                                    }
                                                    if (location2 & 0b000100) != 0 {
                                                        sensorIcon(name: "right_hand", text: "user.page.bind_device.body.rh")
                                                    }
                                                    if (location2 & 0b001000) != 0 {
                                                        sensorIcon(name: "left_foot", text: "user.page.bind_device.body.lf")
                                                    }
                                                    if (location2 & 0b010000) != 0 {
                                                        sensorIcon(name: "right_foot", text: "user.page.bind_device.body.rf")
                                                    }
                                                    if (location2 & 0b100000) != 0 {
                                                        sensorIcon(name: "chest", text: "user.page.bind_device.body.wst")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            // 技能展示
                            Rectangle()
                                .foregroundStyle(Color.thirdText)
                                .frame(height: 1)
                            VStack(alignment: .leading, spacing: 15) {
                                if let des = card.descriptionSkill1 {
                                    skillSection(
                                        skillLevel: 1,
                                        unlockLevel: 3,
                                        description: des
                                    )
                                }
                                if let des = card.descriptionSkill2 {
                                    skillSection(
                                        skillLevel: 2,
                                        unlockLevel: 6,
                                        description: des
                                    )
                                }
                                if let des = card.descriptionSkill3 {
                                    skillSection(
                                        skillLevel: 3,
                                        unlockLevel: 10,
                                        description: des
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        .padding(.bottom, 150)
                    }
                }
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .circular)
                        .fill(backgroundColor)
                        .frame(width: 150, height: 60)
                        .blur(radius: 10)
                    HStack(spacing: 10) {
                        Image(card.ccasset_type.iconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30)
                        Text("\(card.price)")
                            .font(.system(size: 25))
                            .foregroundStyle(Color.white)
                    }
                    .frame(width: 120, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .circular)
                            .fill(Color.orange)
                    )
                }
                .exclusiveTouchTapGesture {
                    PopupWindowManager.shared.presentPopup(
                        title: "shop.action.buy",
                        bottomButtons: [
                            .cancel(),
                            .confirm {
                                AssetManager.shared.purchaseMCWithCC(cardID: card.def_id)
                            }
                        ]
                    ) {
                        RichTextLabel(
                            templateKey: "shop.popup.buy.cpasset",
                            items:
                                [
                                    ("MONEY", .image(card.ccasset_type.iconName, width: 20)),
                                    ("MONEY", .text(" * \(card.price)")),
                                    ("ASSET", .text(card.name))
                                ]
                        )
                    }
                }
                .padding(.bottom, 50)
            }
            .toolbar(.hidden, for: .navigationBar)
            .enableSwipeBackGesture()
            .ignoresSafeArea(edges: .bottom)
        } else {
            VStack(spacing: 50) {
                VStack(spacing: 20) {
                    HStack(spacing: 20) {
                        Rectangle()
                            .frame(height: 32)
                            .foregroundStyle(Color.gray.opacity(0.5))
                            .cornerRadius(16)
                        Image(systemName: "xmark")
                            .fontWeight(.semibold)
                            .frame(width: 20, height: 20)
                            .foregroundColor(.thirdText)
                            .padding(6)
                            .background(Color.gray.opacity(0.5))
                            .clipShape(Circle())
                            .exclusiveTouchTapGesture {
                                navigationManager.removeLast()
                            }
                    }
                    Rectangle()
                        .aspectRatio(5/7, contentMode: .fit)
                        .frame(height: 300)
                        .foregroundStyle(Color.gray.opacity(0.5))
                        .cornerRadius(20)
                }
                .padding(.horizontal)
                Rectangle()
                    .foregroundStyle(Color.gray.opacity(0.3))
            }
            .toolbar(.hidden, for: .navigationBar)
            .enableSwipeBackGesture()
            .ignoresSafeArea(edges: .bottom)
            .background(Color.defaultBackground)
            .onFirstAppear {
                queryShopCardInfo()
            }
        }
    }
    
    func queryShopCardInfo() {
        guard var components = URLComponents(string: "/asset/query_equip_card_shop_detail") else { return }
        components.queryItems = [
            URLQueryItem(name: "def_id", value: defID)
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: MagicCardShopDTO.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        card = MagicCardShop(from: unwrappedData)
                    }
                    downloadImages(url: unwrappedData.image_url)
                }
            default: break
            }
        }
    }
    
    func downloadImages(url: String) {
        NetworkService.downloadImage(from: url) { image in
            if let image = image {
                if let avg = ImageTool.averageColor(from: image) {
                    DispatchQueue.main.async {
                        self.backgroundColor = avg.bestSoftDarkReadableColor()
                    }
                }
            }
        }
    }
    
    // 传感器图标视图
    private func sensorIcon(name: String, text: String) -> some View {
        VStack(spacing: 2) {
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: 25)
            Text(LocalizedStringKey(text))
                .font(.caption)
                .foregroundStyle(Color.white)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.2))
        .cornerRadius(8)
    }
    
    private func skillSection(
        skillLevel: Int,
        unlockLevel: Int,
        description: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("institute.upgrade.skill \(skillLevel)")
                    .font(.headline)
                    .foregroundStyle(Color.white)
                (Text("（level \(unlockLevel.roman) ") + Text("magiccard.detail.skill.unlock") + Text("）"))
                    .font(.subheadline)
                    .foregroundStyle(Color.gray)
                Spacer()
            }
            Text(description)
                .font(.subheadline)
                .foregroundStyle(Color.secondText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/*#Preview() {
    let card = MagicCard(cardID: "qwe", name: "踏频仙人", sportType: .Bike, level: 5, levelSkill1: 2, levelSkill2: 3, levelSkill3: nil, imageURL: "Ads", sensorType: .heartSensor, sensorLocation: 7, lucky: 67.3, rarity: "A", description: "这是一段描述", descriptionSkill1: "技能1的描述", descriptionSkill2: "技能2的描述", descriptionSkill3: nil, version: AppVersion("1.0.0"), tags: [], effectDef: MagicCardDef(cardID: "qwe", typeName: "pedal", params: .string("")))
    MagicCardView(card: card)
}*/
