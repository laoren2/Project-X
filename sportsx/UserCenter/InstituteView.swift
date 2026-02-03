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
                Text("user.page.features.institute")
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
                        Task {
                           await assetManager.queryCCAssets()
                        }
                    }
                HStack(spacing: 4) {
                    AssetCounterView(icon: CCAssetType.stone1.iconName, amount: assetManager.stone1)
                    Button(action:{
                        PopupWindowManager.shared.presentPopup(
                            bottomButtons: []
                        ) {
                            Stone1PurchaseView()
                        }
                    }) {
                        Image(systemName: "plus.rectangle.fill")
                            .foregroundStyle(Color.white)
                            .font(.system(size: 18))
                    }
                }
                HStack(spacing: 4) {
                    AssetCounterView(icon: CCAssetType.stone2.iconName, amount: assetManager.stone2)
                    Button(action:{
                        PopupWindowManager.shared.presentPopup(
                            bottomButtons: []
                        ) {
                            Stone23PurchaseView(assetType: .stone2, price: 10)
                        }
                    }) {
                        Image(systemName: "plus.rectangle.fill")
                            .foregroundStyle(Color.white)
                            .font(.system(size: 18))
                    }
                }
                HStack(spacing: 4) {
                    AssetCounterView(icon: CCAssetType.stone3.iconName, amount: assetManager.stone3)
                    Button(action:{
                        PopupWindowManager.shared.presentPopup(
                            bottomButtons: []
                        ) {
                            Stone23PurchaseView(assetType: .stone3, price: 20)
                        }
                    }) {
                        Image(systemName: "plus.rectangle.fill")
                            .foregroundStyle(Color.white)
                            .font(.system(size: 18))
                    }
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: 20) {
                // 升级方式切换
                Picker("institute.upgrade.upgradeway", selection: $upgradeMethod) {
                    Text("institute.upgrade.upgradeway.mat").tag(0)
                    Text("institute.upgrade.upgradeway.fusion").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // 提示文本
                Text(upgradeMethod == 0 ? "institute.upgrade.upgradeway.mat.content" : "institute.upgrade.upgradeway.fusion.content")
                    .foregroundStyle(Color.secondText)
                    .padding(.horizontal)
                
                // 当前选择的卡牌展示
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        if let card = selectedCard {
                            HStack(spacing: 30) {
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
                                if let level1 = card.levelSkill1 {
                                    VStack {
                                        SkillUpgradeView(skillLevel: 1, unlockLevel: 3, currentLevel: level1, cardLevel: card.level, price: skill1Price)
                                            .exclusiveTouchTapGesture {
                                                guard card.level >= 3 else {
                                                    ToastManager.shared.show(toast: Toast(message: "institute.upgrade.lock"))
                                                    return
                                                }
                                                guard level1 < 5 else {
                                                    ToastManager.shared.show(toast: Toast(message: "institute.upgrade.max_level"))
                                                    return
                                                }
                                                PopupWindowManager.shared.presentPopup(
                                                    title: "institute.upgrade.skill.popup",
                                                    bottomButtons: [
                                                        .cancel(),
                                                        .confirm {
                                                            UpgradeSkill1()
                                                        }
                                                    ]
                                                ) {
                                                    RichTextLabel(
                                                        templateKey: "institute.upgrade.upgradeway.mat.popup",
                                                        items: [
                                                            ("ITEMS", .image(skill1Price.ccasset_type.iconName, width: 20)),
                                                            ("ITEMS", .text(" * \(skill1Price.new_ccamount) "))
                                                        ]
                                                    )
                                                }
                                            }
                                        if let level2 = card.levelSkill2 {
                                            SkillUpgradeView(skillLevel: 2, unlockLevel: 6, currentLevel: level2, cardLevel: card.level, price: skill2Price)
                                                .exclusiveTouchTapGesture {
                                                    guard card.level >= 6 else {
                                                        ToastManager.shared.show(toast: Toast(message: "institute.upgrade.lock"))
                                                        return
                                                    }
                                                    guard level2 < 5 else {
                                                        ToastManager.shared.show(toast: Toast(message: "institute.upgrade.max_level"))
                                                        return
                                                    }
                                                    PopupWindowManager.shared.presentPopup(
                                                        title: "institute.upgrade.skill.popup",
                                                        bottomButtons: [
                                                            .cancel(),
                                                            .confirm {
                                                                UpgradeSkill2()
                                                            }
                                                        ]
                                                    ) {
                                                        RichTextLabel(
                                                            templateKey: "institute.upgrade.upgradeway.mat.popup",
                                                            items: [
                                                                ("ITEMS", .image(skill2Price.ccasset_type.iconName, width: 20)),
                                                                ("ITEMS", .text(" * \(skill2Price.new_ccamount) "))
                                                            ]
                                                        )
                                                    }
                                                }
                                        }
                                        if let level3 = card.levelSkill3 {
                                            SkillUpgradeView(skillLevel: 3, unlockLevel: 10, currentLevel: level3, cardLevel: card.level, price: skill3Price)
                                                .exclusiveTouchTapGesture {
                                                    guard card.level == 10 else {
                                                        ToastManager.shared.show(toast: Toast(message: "institute.upgrade.lock"))
                                                        return
                                                    }
                                                    guard level3 < 5 else {
                                                        ToastManager.shared.show(toast: Toast(message: "institute.upgrade.max_level"))
                                                        return
                                                    }
                                                    PopupWindowManager.shared.presentPopup(
                                                        title: "institute.upgrade.skill.popup",
                                                        bottomButtons: [
                                                            .cancel(),
                                                            .confirm {
                                                                UpgradeSkill3()
                                                            }
                                                        ]
                                                    ) {
                                                        RichTextLabel(
                                                            templateKey: "institute.upgrade.upgradeway.mat.popup",
                                                            items: [
                                                                ("ITEMS", .image(skill3Price.ccasset_type.iconName, width: 20)),
                                                                ("ITEMS", .text(" * \(skill3Price.new_ccamount) "))
                                                            ]
                                                        )
                                                    }
                                                }
                                        }
                                    }
                                }
                            }
                        } else {
                            EmptyCardSlot(text: "institute.upgrade.card")
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
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .onValueChange(of: selectedCard) {
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
                                    Image(price.ccasset_type.iconName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20)
                                    Text("\(price.new_ccamount)")
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                }
                            }
                        }
                    }
                    Text(card.level == 10 ? "institute.upgrade.max_level" : "institute.upgrade.upgradeway.mat")
                        .font(.system(size: 16))
                }
                .padding(.vertical)
                .frame(maxWidth: .infinity)
                .foregroundStyle(Color.white)
                .background(card.level == 10 ? Color.green.opacity(0.8) : Color.orange)
                .cornerRadius(10)
                .exclusiveTouchTapGesture {
                    guard card.level < 10 else {
                        ToastManager.shared.show(toast: Toast(message: "institute.upgrade.max_level"))
                        return
                    }
                    PopupWindowManager.shared.presentPopup(
                        title: "institute.upgrade.upgradeway.mat",
                        bottomButtons: [
                            .cancel(),
                            .confirm {
                                performMatUpgrade()
                            }
                        ]
                    ) {
                        RichTextLabel(
                            templateKey: "institute.upgrade.upgradeway.mat.popup",
                            items: cardPrices.flatMap { price -> [(String, RichTextItem)] in
                                [
                                    ("ITEMS", .image(price.ccasset_type.iconName, width: 20)),
                                    ("ITEMS", .text(" * \(price.new_ccamount) "))
                                ]
                            }
                        )
                    }
                }
            } else {
                Text("institute.upgrade.upgradeway.mat")
                    .font(.system(size: 16))
                    .padding(.vertical)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(Color.secondText)
                    .background(Color.gray)
                    .cornerRadius(10)
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
                EmptyCardSlot(text: "institute.upgrade.fusion_card")
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
                                    .frame(height: 100)
                                    .onTapGesture {
                                        // 选择要消耗的卡牌
                                        selectedFusionCard = card
                                        showFusionSelectedView = false
                                    }
                            }
                        }
                        .padding(5)
                    }
                } else {
                    Text("institute.upgrade.fusion_card.none")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.thirdText)
                }
            }
            if let card = selectedCard, let fusion = selectedFusionCard {
                Text(card.level == 10 ? "institute.upgrade.max_level" : "institute.upgrade.action")
                    .padding(.vertical)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(Color.white)
                    .background(card.level == 10 ? Color.green.opacity(0.8) : Color.orange)
                    .cornerRadius(10)
                    .exclusiveTouchTapGesture {
                        guard card.level < 10 else {
                            ToastManager.shared.show(toast: Toast(message: "institute.upgrade.max_level"))
                            return
                        }
                        PopupWindowManager.shared.presentPopup(
                            title: "institute.upgrade.upgradeway.fusion",
                            bottomButtons: [
                                .cancel(),
                                .confirm {
                                    performFusionUpgrade()
                                }
                            ]
                        ) {
                            RichTextLabel(
                                templateKey: "institute.upgrade.upgradeway.fusion.popup",
                                items: [("ITEMS", .text(fusion.name))]
                            )
                        }
                    }
            } else {
                Text("institute.upgrade.action")
                    .padding(.vertical)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(Color.secondText)
                    .background(Color.gray)
                    .cornerRadius(10)
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
        guard let card = selectedCard, card.level >= 0 else { return }
        
        guard var components = URLComponents(string: "/asset/upgrade_equip_card_mat") else { return }
        components.queryItems = [
            URLQueryItem(name: "card_id", value: card.cardID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        NetworkService.sendRequest(with: request, decodingType: MagicCardMatUpgradeResponse.self, showLoadingToast: true, showErrorToast: true) { result in
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
                        ToastManager.shared.show(toast: Toast(message: "institute.upgrade.toast.success"))
                    }
                }
            default: break
            }
        }
    }
    
    private func performFusionUpgrade() {
        guard let card = selectedCard, let fusionCard = selectedFusionCard, card.level >= 0 else { return }
        
        guard var components = URLComponents(string: "/asset/upgrade_equip_card_fusion") else { return }
        components.queryItems = [
            URLQueryItem(name: "card_id", value: card.cardID),
            URLQueryItem(name: "fusion_card_id", value: fusionCard.cardID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        NetworkService.sendRequest(with: request, decodingType: MagicCardUserDTO.self, showLoadingToast: true, showErrorToast: true) { result in
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
                        ToastManager.shared.show(toast: Toast(message: "institute.upgrade.toast.success"))
                    }
                }
            default: break
            }
        }
    }
    
    func UpgradeSkill1() {
        guard let card = selectedCard, let skillLevel = card.levelSkill1, skillLevel >= 0 else { return }
        
        guard var components = URLComponents(string: "/asset/upgrade_equip_card_skill1") else { return }
        components.queryItems = [
            URLQueryItem(name: "card_id", value: card.cardID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        NetworkService.sendRequest(with: request, decodingType: MagicCardSkillUpgradeResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        assetManager.updateCCAsset(type: unwrappedData.ccasset.ccasset_type, newBalance: unwrappedData.ccasset.new_ccamount)
                        if let index = assetManager.magicCards.firstIndex(where: { $0.cardID == unwrappedData.card.card_id }) {
                            assetManager.magicCards[index] = MagicCard(from: unwrappedData.card)
                            selectedCard = assetManager.magicCards[index]
                        }
                        ToastManager.shared.show(toast: Toast(message: "institute.upgrade.toast.success"))
                    }
                }
            default: break
            }
        }
    }
    
    func UpgradeSkill2() {
        guard let card = selectedCard, let skillLevel = card.levelSkill2, skillLevel >= 0 else { return }
        
        guard var components = URLComponents(string: "/asset/upgrade_equip_card_skill2") else { return }
        components.queryItems = [
            URLQueryItem(name: "card_id", value: card.cardID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        NetworkService.sendRequest(with: request, decodingType: MagicCardSkillUpgradeResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        assetManager.updateCCAsset(type: unwrappedData.ccasset.ccasset_type, newBalance: unwrappedData.ccasset.new_ccamount)
                        if let index = assetManager.magicCards.firstIndex(where: { $0.cardID == unwrappedData.card.card_id }) {
                            assetManager.magicCards[index] = MagicCard(from: unwrappedData.card)
                            selectedCard = assetManager.magicCards[index]
                        }
                        ToastManager.shared.show(toast: Toast(message: "institute.upgrade.toast.success"))
                    }
                }
            default: break
            }
        }
    }
    
    func UpgradeSkill3() {
        guard let card = selectedCard, let skillLevel = card.levelSkill3, skillLevel >= 0 else { return }
        
        guard var components = URLComponents(string: "/asset/upgrade_equip_card_skill3") else { return }
        components.queryItems = [
            URLQueryItem(name: "card_id", value: card.cardID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        NetworkService.sendRequest(with: request, decodingType: MagicCardSkillUpgradeResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        assetManager.updateCCAsset(type: unwrappedData.ccasset.ccasset_type, newBalance: unwrappedData.ccasset.new_ccamount)
                        if let index = assetManager.magicCards.firstIndex(where: { $0.cardID == unwrappedData.card.card_id }) {
                            assetManager.magicCards[index] = MagicCard(from: unwrappedData.card)
                            selectedCard = assetManager.magicCards[index]
                        }
                        ToastManager.shared.show(toast: Toast(message: "institute.upgrade.toast.success"))
                    }
                }
            default: break
            }
        }
    }
}

struct Stone1PurchaseView: View {
    @ObservedObject var assetManager = AssetManager.shared
    
    @State var stone1Count: Int = 1
    
    var body: some View {
        VStack(spacing: 20) {
            (Text("shop.action.buy") + Text("ccasset.stone"))
                .font(.title3.bold())
                .foregroundColor(.white)
            RichTextLabel(
                templateKey: "shop.popup.buy.ccasset.stone1",
                items:
                    [
                        ("MONEY", .image(CCAssetType.coin.iconName, width: 20)),
                        ("ASSET", .image(CCAssetType.stone1.iconName, width: 20))
                    ]
            )
            if stone1Count < 1 {
                Text("shop.popup.buy.stone.error")
                    .font(.caption)
                    .foregroundStyle(Color.pink)
            }
            HStack(spacing: 12) {
                TextField("0", value: $stone1Count, formatter: NumberFormatter())
                    .keyboardType(.numberPad)
                    .foregroundColor(.white)
                    .font(.system(size: 20, weight: .semibold))
                    .padding(10)
                    .frame(height: 40)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                    .onValueChange(of: stone1Count) {
                        if stone1Count > 999 {
                            stone1Count = 999
                        }
                    }
                HStack(spacing: 6) {
                    Button("+1") { stone1Count += 1 }
                        .padding(.horizontal, 6)
                        .frame(height: 40)
                        .background(Color.black.opacity(0.25))
                        .cornerRadius(6)
                    Button("+10") { stone1Count += 10 }
                        .padding(.horizontal, 6)
                        .frame(height: 40)
                        .background(Color.black.opacity(0.25))
                        .cornerRadius(6)
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white)
            }
            HStack(spacing: 30) {
                Button {
                    _ = PopupWindowManager.shared.dismissPopup()
                    PopupWindowManager.shared.presentPopup(
                        title: "shop.action.buy",
                        bottomButtons: [
                            .cancel(),
                            .confirm {
                                assetManager.purchaseCCWithCC(buy: .stone1, amount: stone1Count, use: .coin)
                            }
                        ]
                    ) {
                        RichTextLabel(
                            templateKey: "shop.popup.buy.ccasset.confirm",
                            items:
                                [
                                    ("MONEY", .image(CCAssetType.coin.iconName, width: 20)),
                                    ("MONEYCOUNT", .text("\(Int(stone1Count * 100))")),
                                    ("ASSET", .image(CCAssetType.stone1.iconName, width: 20)),
                                    ("ASSETCOUNT", .text("\(stone1Count)"))
                                ]
                        )
                    }
                } label: {
                    HStack {
                        Image("coin")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20)
                        Text("\(Int(stone1Count * 100))")
                            .foregroundStyle(Color.white)
                    }
                    .padding(10)
                    .background(stone1Count > 0 ? Color.orange : Color.gray)
                    .cornerRadius(10)
                }
                .disabled(stone1Count < 1)
            }
        }
    }
}

struct Stone23PurchaseView: View {
    @ObservedObject var assetManager = AssetManager.shared
    @State var stoneCount: Int = 1
    let assetType: CCAssetType
    let price: Int
    
    var body: some View {
        VStack(spacing: 20) {
            (Text("shop.action.buy") + Text("ccasset.stone"))
                .font(.title3.bold())
                .foregroundColor(.white)
            RichTextLabel(
                templateKey: "shop.popup.buy.ccasset.coin",
                items:
                    [
                        ("MONEY1", .image(CCAssetType.coupon.iconName, width: 20)),
                        ("MONEY2", .image(CCAssetType.voucher.iconName, width: 20)),
                        ("ASSET", .image(assetType.iconName, width: 20))
                    ]
            )
            if stoneCount < 1 {
                Text("shop.popup.buy.stone.error")
                    .font(.caption)
                    .foregroundStyle(Color.pink)
            }
            HStack(spacing: 12) {
                TextField("0", value: $stoneCount, formatter: NumberFormatter())
                    .keyboardType(.numberPad)
                    .foregroundColor(.white)
                    .font(.system(size: 20, weight: .semibold))
                    .padding(10)
                    .frame(height: 40)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                    .onValueChange(of: stoneCount) {
                        if stoneCount > 999 {
                            stoneCount = 999
                        }
                    }
                HStack(spacing: 6) {
                    Button("+1") { stoneCount += 1 }
                        .padding(.horizontal, 6)
                        .frame(height: 40)
                        .background(Color.black.opacity(0.25))
                        .cornerRadius(6)
                    Button("+10") { stoneCount += 10 }
                        .padding(.horizontal, 6)
                        .frame(height: 40)
                        .background(Color.black.opacity(0.25))
                        .cornerRadius(6)
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white)
            }
            HStack(spacing: 30) {
                Button {
                    _ = PopupWindowManager.shared.dismissPopup()
                    PopupWindowManager.shared.presentPopup(
                        title: "shop.action.buy",
                        bottomButtons: [
                            .cancel(),
                            .confirm {
                                assetManager.purchaseCCWithCC(buy: assetType, amount: stoneCount, use: .coupon)
                            }
                        ]
                    ) {
                        RichTextLabel(
                            templateKey: "shop.popup.buy.ccasset.confirm",
                            items:
                                [
                                    ("MONEY", .image(CCAssetType.coupon.iconName, width: 20)),
                                    ("MONEYCOUNT", .text("\(Int(stoneCount * price))")),
                                    ("ASSET", .image(assetType.iconName, width: 20)),
                                    ("ASSETCOUNT", .text("\(stoneCount)"))
                                ]
                        )
                    }
                } label: {
                    HStack {
                        Image("coupon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20)
                        Text("\(Int(stoneCount * price))")
                            .foregroundStyle(Color.white)
                    }
                    .padding(10)
                    .background(stoneCount > 0 ? Color.orange : Color.gray)
                    .cornerRadius(10)
                }
                .disabled(stoneCount < 1)
                Button {
                    _ = PopupWindowManager.shared.dismissPopup()
                    PopupWindowManager.shared.presentPopup(
                        title: "shop.action.buy",
                        bottomButtons: [
                            .cancel(),
                            .confirm {
                                assetManager.purchaseCCWithCC(buy: assetType, amount: stoneCount, use: .voucher)
                            }
                        ]
                    ) {
                        RichTextLabel(
                            templateKey: "shop.popup.buy.ccasset.confirm",
                            items:
                                [
                                    ("MONEY", .image(CCAssetType.voucher.iconName, width: 20)),
                                    ("MONEYCOUNT", .text("\(Int(stoneCount * price))")),
                                    ("ASSET", .image(assetType.iconName, width: 20)),
                                    ("ASSETCOUNT", .text("\(stoneCount)"))
                                ]
                        )
                    }
                } label: {
                    HStack {
                        Image("voucher")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20)
                        Text("\(Int(stoneCount * price))")
                            .foregroundStyle(Color.white)
                    }
                    .padding(10)
                    .background(stoneCount > 0 ? Color.orange : Color.gray)
                    .cornerRadius(10)
                }
                .disabled(stoneCount < 1)
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
                    Text("action.cancel")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.thirdText)
                }
                
                Spacer()
                
                Text("institute.upgrade.card.select")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.secondText)
                
                Spacer()
                
                Text("action.cancel")
                    .font(.system(size: 16))
                    .foregroundStyle(.clear)
            }
            .padding()
            
            // 卡牌列表
            if assetManager.magicCards.isEmpty {
                Text("institute.upgrade.card.none")
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
    let skillLevel: Int
    let unlockLevel: Int
    let currentLevel: Int
    let cardLevel: Int
    let price: CCUpdateResponse
    var isUnlocked: Bool { return cardLevel >= unlockLevel }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 20) {
                Text("institute.upgrade.skill \(skillLevel)")
                if isUnlocked {
                    if currentLevel == 5 {
                        Text("institute.upgrade.max_level")
                    } else {
                        HStack(spacing: 4) {
                            Image(price.ccasset_type.iconName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20)
                            Text("\(price.new_ccamount)")
                            Image(systemName: "arrowshape.up")
                        }
                    }
                } else {
                    Text("institute.upgrade.lock")
                }
            }
            .font(.system(size: 15))
            
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in
                    Rectangle()
                        .fill(isUnlocked ? (i < currentLevel ? Color.orange : Color.black.opacity(0.5)) : Color.gray)
                        .frame(width: 12, height: 12)
                        .cornerRadius(2)
                }
            }
        }
        .padding()
        .foregroundStyle(isUnlocked ? Color.white : Color.gray)
        .background(isUnlocked ? (currentLevel == 5 ? Color.green.opacity(0.8) : Color.white.opacity(0.5)) : Color.gray.opacity(0.5))
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

struct RichTextLabel: UIViewRepresentable {
    let attributedText: NSAttributedString
    let font: UIFont
    let textColor: UIColor
    
    init(
        templateKey: String,
        items: [(String, RichTextItem)],
        font: UIFont = .systemFont(ofSize: 18),
        textColor: UIColor = .white
    ) {
        self.font = font
        self.textColor = textColor
        self.attributedText = RichTextGenerator.attributedText(
            templateKey: templateKey,
            items: items,
            font: font,
            textColor: textColor
        )
    }
    
    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isScrollEnabled = false            // 不滚动
        tv.isEditable = false                 // 不编辑
        tv.isSelectable = false               // 不选中
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero         // 去掉内边距
        tv.textContainer.lineFragmentPadding = 0
        tv.textContainer.widthTracksTextView = true
        tv.font = font
        tv.textColor = textColor
        tv.textAlignment = .justified
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return tv
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = attributedText
        uiView.textAlignment = .center
    }
    
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UITextView,
        context: Context
    ) -> CGSize? {
        if let width = proposal.width {
            let targetSize = CGSize(width: width, height: .greatestFiniteMagnitude)
            let size = uiView.sizeThatFits(targetSize)
            return CGSize(width: width, height: size.height)
        }
        return nil
    }
}
