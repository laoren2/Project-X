//
//  InstituteView.swift
//  sportsx
//
//  Created by 任杰 on 2025/4/18.
//

import SwiftUI

struct InstituteView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var assetManager = AssetManager.shared
    @State private var selectedCard: MagicCard? = nil
    @State private var selectedFusionCard: MagicCard? = nil
    @State private var showSelectedView: Bool = false
    @State private var showFusionSelectedView: Bool = false
    @State private var upgradeMethod: Int = 0
    
    @State var cardPrices: [CCUpdateResponse] = []
    @State var skill1Price: CCUpdateResponse = CCUpdateResponse(ccasset_type: .coin, new_ccamount: 0)
    @State var skill2Price: CCUpdateResponse = CCUpdateResponse(ccasset_type: .coin, new_ccamount: 0)
    @State var skill3Price: CCUpdateResponse = CCUpdateResponse(ccasset_type: .coin, new_ccamount: 0)
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    appState.navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.secondText)
                Spacer()
                Text("研究所")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.secondText)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            .padding(.horizontal)
            
            // 顶部资产栏
            HStack(spacing: 15) {
                Spacer()
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.secondText)
                    .onTapGesture {
                        assetManager.queryCCAssets()
                    }
                AssetCounterView(icon: CCAssetType.stone1.iconName, amount: assetManager.stone1)
                AssetCounterView(icon: CCAssetType.stone2.iconName, amount: assetManager.stone2)
                AssetCounterView(icon: CCAssetType.stone3.iconName, amount: assetManager.stone3)
            }
            .padding(.horizontal)
            
            VStack(spacing: 20) {
                // 升级方式切换
                Picker("升级方式", selection: $upgradeMethod) {
                    Text("材料升级").tag(0)
                    Text("卡牌融合").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // 当前选择的卡牌展示
                if let card = selectedCard {
                    HStack {
                        Spacer()
                        ZStack(alignment: .topTrailing) {
                            MagicCardView(card: card)
                                .frame(height: 200)
                            Button(action: {
                                selectedCard = nil
                                selectedFusionCard = nil
                                showFusionSelectedView = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .background(Circle().fill(Color.white))
                                    .shadow(radius: 1)
                            }
                            .offset(x: 8, y: -8)
                        }
                        Spacer()
                        VStack {
                            if let level1 = card.levelSkill1 {
                                SkillUpgradeView(title: "技能1", unlockLevel: 3, currentLevel: level1, cardLevel: card.level, price: skill1Price)
                                    .exclusiveTouchTapGesture {
                                        UpgradeSkill1()
                                    }
                            }
                            if let level2 = card.levelSkill2 {
                                SkillUpgradeView(title: "技能2", unlockLevel: 6, currentLevel: level2, cardLevel: card.level, price: skill2Price)
                                    .exclusiveTouchTapGesture {
                                        UpgradeSkill2()
                                    }
                            }
                            if let level3 = card.levelSkill3 {
                                SkillUpgradeView(title: "技能3", unlockLevel: 10, currentLevel: level3, cardLevel: card.level, price: skill3Price)
                                    .exclusiveTouchTapGesture {
                                        UpgradeSkill3()
                                    }
                            }
                        }
                        Spacer()
                    }
                } else {
                    EmptyCardSlot(text: "选择卡牌升级")
                        .frame(height: 200)
                        .exclusiveTouchTapGesture {
                            showSelectedView = true
                        }
                }
                
                if upgradeMethod == 0 {
                    materialUpgradeView
                } else {
                    fusionUpgradeView
                }
                Spacer()
            }
            .padding(.horizontal)
        }
        .environment(\.colorScheme, .dark)
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableBackGesture()
        .onChange(of: selectedCard) {
            if let card = selectedCard {
                queryUpgradePrice(cardID: card.cardID)
                querySkill1UpgradePrice(card: card)
                querySkill2UpgradePrice(card: card)
                querySkill3UpgradePrice(card: card)
            }
        }
        .bottomSheet(isPresented: $showSelectedView, size: .medium) {
            CardSelectedSheetView(showCardSheet: $showSelectedView, selectedCard: $selectedCard)
        }
    }
    
    // 材料升级 UI
    private var materialUpgradeView: some View {
        VStack(spacing: 20) {
            //Text("消耗材料进行升级")
            //    .font(.system(size: 15))
            //    .foregroundStyle(Color.secondText)
            
            if let card = selectedCard {
                VStack(spacing: 2) {
                    if !cardPrices.isEmpty {
                        HStack {
                            ForEach(cardPrices) { price in
                                HStack(spacing: 4) {
                                    Image(systemName: price.ccasset_type.iconName)
                                    Text("\(price.new_ccamount)")
                                }
                                .font(.system(size: 12))
                            }
                        }
                    }
                    Text(card.level == 10 ? "已满级" : "材料升级")
                        .font(.system(size: 16))
                }
                .padding()
                .foregroundStyle(Color.secondText)
                .background(card.level == 10 ? Color.green : Color.orange)
                .cornerRadius(10)
                .exclusiveTouchTapGesture {
                    performMatUpgrade()
                }
            } else {
                Text("材料升级")
                    .font(.system(size: 16))
                    .padding()
                    .foregroundStyle(Color.secondText)
                    .background(Color.orange)
                    .cornerRadius(10)
                    .exclusiveTouchTapGesture {
                        ToastManager.shared.show(toast: Toast(message: "请选择卡牌"))
                    }
            }
        }
    }
    
    // 卡牌融合 UI
    private var fusionUpgradeView: some View {
        VStack(spacing: 20) {
            //Text("融合重复卡牌进行升级")
            //    .font(.system(size: 15))
            //    .foregroundStyle(Color.secondText)
            // 当前选择的卡牌展示
            if let card = selectedFusionCard {
                ZStack(alignment: .topTrailing) {
                    MagicCardView(card: card)
                        .frame(height: 120)
                    Button(action: {
                        selectedFusionCard = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .background(Circle().fill(Color.white))
                            .shadow(radius: 1)
                    }
                    .offset(x: 8, y: -8)
                }
            } else {
                EmptyCardSlot(text: "选择卡牌融合")
                    .frame(height: 120)
                    .exclusiveTouchTapGesture {
                        showFusionSelectedView.toggle()
                    }
            }
            if showFusionSelectedView {
                let filteredCards = assetManager.magicCards.filter {
                    $0.cardID != selectedCard?.cardID &&
                    $0.defID == selectedCard?.defID &&
                    $0.level == 0
                }
                if !filteredCards.isEmpty {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(filteredCards) { card in
                                MagicCardView(card: card)
                                    .frame(width: 50)
                                    .onTapGesture {
                                        // 选择要消耗的卡牌
                                        selectedFusionCard = card
                                        showFusionSelectedView = false
                                    }
                            }
                        }
                    }
                } else {
                    Text("暂无可融合的卡牌")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.thirdText)
                }
            }
            if let card = selectedCard {
                Text(card.level == 10 ? "已满级" : "融合升级")
                    .padding()
                    .foregroundStyle(Color.secondText)
                    .background(card.level == 10 ? Color.green : Color.orange)
                    .cornerRadius(10)
                    .exclusiveTouchTapGesture {
                        performFusionUpgrade()
                    }
            } else {
                Text("融合升级")
                    .padding()
                    .foregroundStyle(Color.secondText)
                    .background(Color.orange)
                    .cornerRadius(10)
                    .exclusiveTouchTapGesture {
                        performFusionUpgrade()
                    }
            }
        }
    }
    
    func queryUpgradePrice(cardID: String) {
        guard var components = URLComponents(string: "/asset/query_equip_card_upgrade_price") else { return }
        components.queryItems = [
            URLQueryItem(name: "card_id", value: cardID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: UpgradePriceResponse.self) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        cardPrices = unwrappedData.prices
                    }
                }
            default: break
            }
        }
    }
    
    func querySkill1UpgradePrice(card: MagicCard) {
        guard card.levelSkill1 != nil, card.level >= 3 else { return }
        
        guard var components = URLComponents(string: "/asset/query_equip_card_skill1_upgrade_price") else { return }
        components.queryItems = [
            URLQueryItem(name: "card_id", value: card.cardID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: CCUpdateResponse.self) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        skill1Price = unwrappedData
                    }
                }
            default: break
            }
        }
    }
    
    func querySkill2UpgradePrice(card: MagicCard) {
        guard card.levelSkill2 != nil, card.level >= 6 else { return }
        
        guard var components = URLComponents(string: "/asset/query_equip_card_skill2_upgrade_price") else { return }
        components.queryItems = [
            URLQueryItem(name: "card_id", value: card.cardID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: CCUpdateResponse.self) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        skill2Price = unwrappedData
                    }
                }
            default: break
            }
        }
    }
    
    func querySkill3UpgradePrice(card: MagicCard) {
        guard card.levelSkill3 != nil, card.level == 10 else { return }
        
        guard var components = URLComponents(string: "/asset/query_equip_card_skill3_upgrade_price") else { return }
        components.queryItems = [
            URLQueryItem(name: "card_id", value: card.cardID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: CCUpdateResponse.self) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        skill3Price = unwrappedData
                    }
                }
            default: break
            }
        }
    }
    
    private func performMatUpgrade() {
        guard let card = selectedCard else {
            ToastManager.shared.show(toast: Toast(message: "请选择卡牌"))
            return
        }
        guard card.level >= 0 && card.level < 10 else { return }
        
        guard var components = URLComponents(string: "/asset/upgrade_equip_card_mat") else { return }
        components.queryItems = [
            URLQueryItem(name: "card_id", value: card.cardID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        NetworkService.sendRequest(with: request, decodingType: MagicCardMatUpgradeResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        for info in unwrappedData.ccassets {
                            assetManager.updateCCAsset(type: info.ccasset_type, newBalance: info.new_ccamount)
                        }
                        if let index = assetManager.magicCards.firstIndex(where: { $0.cardID == unwrappedData.card.card_id }) {
                            assetManager.magicCards[index] = MagicCard(from: unwrappedData.card)
                            selectedCard = assetManager.magicCards[index]
                        }
                    }
                }
            default: break
            }
        }
    }
    
    private func performFusionUpgrade() {
        guard let card = selectedCard, let fusionCard = selectedFusionCard else { return }
        guard card.level >= 0 && card.level < 10 else { return }
        
        guard var components = URLComponents(string: "/asset/upgrade_equip_card_fusion") else { return }
        components.queryItems = [
            URLQueryItem(name: "card_id", value: card.cardID),
            URLQueryItem(name: "fusion_card_id", value: fusionCard.cardID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        NetworkService.sendRequest(with: request, decodingType: MagicCardUserDTO.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        if let index = assetManager.magicCards.firstIndex(where: { $0.cardID == fusionCard.cardID }) {
                            assetManager.magicCards.remove(at: index)
                            selectedFusionCard = nil
                        }
                        if let index = assetManager.magicCards.firstIndex(where: { $0.cardID == unwrappedData.card_id }) {
                            assetManager.magicCards[index] = MagicCard(from: unwrappedData)
                            selectedCard = assetManager.magicCards[index]
                        }
                    }
                }
            default: break
            }
        }
    }
    
    func UpgradeSkill1() {
        guard let card = selectedCard, let skillLevel = card.levelSkill1 else { return }
        guard card.level >= 3 else {
            ToastManager.shared.show(toast: Toast(message: "未解锁"))
            return
        }
        guard skillLevel >= 0 && skillLevel < 5 else { return }
        
        guard var components = URLComponents(string: "/asset/upgrade_equip_card_skill1") else { return }
        components.queryItems = [
            URLQueryItem(name: "card_id", value: card.cardID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        NetworkService.sendRequest(with: request, decodingType: MagicCardSkillUpgradeResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        assetManager.updateCCAsset(type: unwrappedData.ccasset.ccasset_type, newBalance: unwrappedData.ccasset.new_ccamount)
                        if let index = assetManager.magicCards.firstIndex(where: { $0.cardID == unwrappedData.card.card_id }) {
                            assetManager.magicCards[index] = MagicCard(from: unwrappedData.card)
                            selectedCard = assetManager.magicCards[index]
                        }
                    }
                }
            default: break
            }
        }
    }
    
    func UpgradeSkill2() {
        guard let card = selectedCard, let skillLevel = card.levelSkill2 else { return }
        guard card.level >= 6 else {
            ToastManager.shared.show(toast: Toast(message: "未解锁"))
            return
        }
        guard skillLevel >= 0 && skillLevel < 5 else { return }
        
        guard var components = URLComponents(string: "/asset/upgrade_equip_card_skill2") else { return }
        components.queryItems = [
            URLQueryItem(name: "card_id", value: card.cardID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        NetworkService.sendRequest(with: request, decodingType: MagicCardSkillUpgradeResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        assetManager.updateCCAsset(type: unwrappedData.ccasset.ccasset_type, newBalance: unwrappedData.ccasset.new_ccamount)
                        if let index = assetManager.magicCards.firstIndex(where: { $0.cardID == unwrappedData.card.card_id }) {
                            assetManager.magicCards[index] = MagicCard(from: unwrappedData.card)
                            selectedCard = assetManager.magicCards[index]
                        }
                    }
                }
            default: break
            }
        }
    }
    
    func UpgradeSkill3() {
        guard let card = selectedCard, let skillLevel = card.levelSkill3 else { return }
        guard card.level == 10 else {
            ToastManager.shared.show(toast: Toast(message: "未解锁"))
            return
        }
        guard skillLevel >= 0 && skillLevel < 5 else { return }
        
        guard var components = URLComponents(string: "/asset/upgrade_equip_card_skill3") else { return }
        components.queryItems = [
            URLQueryItem(name: "card_id", value: card.cardID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        NetworkService.sendRequest(with: request, decodingType: MagicCardSkillUpgradeResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        assetManager.updateCCAsset(type: unwrappedData.ccasset.ccasset_type, newBalance: unwrappedData.ccasset.new_ccamount)
                        if let index = assetManager.magicCards.firstIndex(where: { $0.cardID == unwrappedData.card.card_id }) {
                            assetManager.magicCards[index] = MagicCard(from: unwrappedData.card)
                            selectedCard = assetManager.magicCards[index]
                        }
                    }
                }
            default: break
            }
        }
    }
}

struct CardSelectedSheetView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var assetManager = AssetManager.shared
    @Binding var showCardSheet: Bool
    @Binding var selectedCard: MagicCard?
    
    // 卡牌容器的常量
    private let cardWidth: CGFloat = 100
    private let cardHeight: CGFloat = 140
    private let maxCards = 3
    
    // 定义4列网格
    let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    showCardSheet = false
                }) {
                    Text("取消")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.thirdText)
                }
                
                Spacer()
                
                Text("选择技能卡")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.secondText)
                
                Spacer()
                
                Text("完成")
                    .font(.system(size: 16))
                    .foregroundStyle(.clear)
            }
            .padding()
            
            // 卡牌列表
            if assetManager.magicCards.isEmpty {
                Text("无可用卡牌")
                    .padding()
                    .foregroundStyle(Color.secondText)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(assetManager.magicCards) { card in
                            MagicCardView(card: card)
                                .onTapGesture {
                                    selectedCard = card
                                    showCardSheet = false
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color.defaultBackground)
        .onFirstAppear {
            if assetManager.magicCards.isEmpty {
                Task {
                    await assetManager.queryMagicCards(withLoadingToast: false)
                }
            }
        }
    }
}

struct SkillUpgradeView: View {
    let title: String
    let unlockLevel: Int
    let currentLevel: Int
    let cardLevel: Int
    let price: CCUpdateResponse
    var isUnlocked: Bool { return cardLevel >= unlockLevel }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 20) {
                Text("\(title)")
                if isUnlocked {
                    if currentLevel == 5 {
                        Text("已满级")
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: price.ccasset_type.iconName)
                            Text("\(price.new_ccamount)")
                            Image(systemName: "arrowshape.up")
                        }
                    }
                } else {
                    Text("（未解锁）")
                }
            }
            .font(.system(size: 15))
            
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in
                    Rectangle()
                        .fill(i < currentLevel && isUnlocked ? Color.orange : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .cornerRadius(2)
                }
            }
        }
        .padding()
        .foregroundColor(isUnlocked ? .secondText : .gray)
        .background(isUnlocked ? Color.orange.opacity(0.5) : Color.gray.opacity(0.5))
        .cornerRadius(10)
    }
}

struct MagicCardMatUpgradeResponse: Codable {
    let ccassets: [CCUpdateResponse]
    let card: MagicCardUserDTO
}

struct MagicCardSkillUpgradeResponse: Codable {
    let ccasset: CCUpdateResponse
    let card: MagicCardUserDTO
}

struct UpgradePriceResponse: Codable {
    let prices: [CCUpdateResponse]
}

#Preview() {
    let state = AppState.shared
    return InstituteView()
        .environmentObject(state)
}
