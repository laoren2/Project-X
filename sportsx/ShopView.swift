//
//  ShopView.swift
//  sportsx
//
//  Created by 任杰 on 2025/7/2.
//

import SwiftUI


struct ShopView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var assetManager = AssetManager.shared
    @State var cpassets: [CPAssetShopInfo] = []
    @State var magicCards: [MagicCardShop] = []
    @State var selectedAsset: CPAssetShopInfo? = nil
    @State var selectedCard: MagicCardShop? = nil
    @State var selectedTab: Int = 0
    @State private var firstOnAppear = true
    let globalConfig = GlobalConfig.shared
    
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .defaultBackground.softenColor(blendWithWhiteRatio: 0.2),
                            .defaultBackground
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部资产栏
                HStack(spacing: 15) {
                    Spacer()
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.secondText)
                        .onTapGesture {
                            assetManager.queryCCAssets()
                        }
                    AssetCounterView(icon: CCAssetType.coin.iconName, amount: assetManager.coin)
                    AssetCounterView(icon: CCAssetType.coupon.iconName, amount: assetManager.coupon)
                    AssetCounterView(icon: CCAssetType.voucher.iconName, amount: assetManager.voucher)
                }
                .padding(10)
                
                HStack(spacing: 0) {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            Text("道具")
                                .font(.system(size: 16, weight: selectedTab == 0 ? .semibold : .regular))
                                .foregroundColor(selectedTab == 0 ? Color.white : Color.thirdText)
                            Rectangle()
                                .fill(selectedTab == 0 ? Color.white : Color.clear)
                                .frame(width: 40, height: 2)
                        }
                        Spacer()
                    }
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = 0
                        }
                    }
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            Text("装备卡")
                                .font(.system(size: 16, weight: selectedTab == 1 ? .semibold : .regular))
                                .foregroundColor(selectedTab == 1 ? Color.white : Color.thirdText)
                            Rectangle()
                                .fill(selectedTab == 1 ? Color.white : Color.clear)
                                .frame(width: 40, height: 2)
                        }
                        Spacer()
                    }
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = 1
                        }
                    }
                }
                
                Divider()
                
                TabView(selection: $selectedTab) {
                    GeometryReader { geo in
                        let itemSpacing: CGFloat = 10
                        let columnCount = 5
                        let totalSpacing = itemSpacing * CGFloat(columnCount - 1)
                        let itemWidth = (geo.size.width - totalSpacing - 20) / CGFloat(columnCount) // 20为ScrollView两侧padding

                        ZStack(alignment: .bottom) {
                            ScrollView {
                                LazyVGrid(columns: Array(repeating: GridItem(.fixed(itemWidth), spacing: itemSpacing), count: columnCount), spacing: 10) {
                                    ForEach(cpassets) { asset in
                                        CPAssetShopCardView(asset: asset)
                                            .frame(width: itemWidth)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(selectedAsset?.id == asset.id ? Color.orange : Color.clear, lineWidth: 2)
                                            )
                                            .onTapGesture {
                                                if selectedAsset?.id == asset.id {
                                                    selectedAsset = nil
                                                } else {
                                                    selectedAsset = asset
                                                }
                                            }
                                    }
                                }
                                .padding(10)
                            }
                            .refreshable {
                                selectedAsset = nil
                                await queryCPAssets(withLoadingToast: false)
                            }
                            if let selected = selectedAsset {
                                HStack(alignment: .bottom, spacing: 20) {
                                    VStack(alignment: .leading) {
                                        HStack(spacing: 4) {
                                            Text(selected.name)
                                                .bold()
                                            Spacer()
                                            Image(systemName: selected.ccassetType.iconName)
                                            Text("\(selected.price)")
                                        }
                                        .font(.system(size: 15))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 5)
                                        
                                        ScrollView {
                                            Text(selected.description)
                                                .font(.system(size: 12))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(4)
                                        }
                                        .frame(height: 48)
                                        .padding(6)
                                        .background(Color.gray.opacity(0.8))
                                        .cornerRadius(10)
                                    }
                                    Text("购买")
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.orange)
                                        .cornerRadius(8)
                                        .onTapGesture {
                                            assetManager.purchaseCPWithCC(assetID: selected.asset_id, amount: 1)
                                        }
                                }
                                .padding()
                                .background(Color.black)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .background(Color.gray.opacity(0.2))
                    .tag(0)
                    
                    GeometryReader { geo in
                        let itemSpacing: CGFloat = 20
                        let columnCount = 3
                        let totalSpacing = itemSpacing * CGFloat(columnCount - 1)
                        let itemWidth = (geo.size.width - totalSpacing - 40) / CGFloat(columnCount) // 40为ScrollView两侧padding
                        
                        ZStack(alignment: .bottom) {
                            ScrollView {
                                LazyVGrid(columns: Array(repeating: GridItem(.fixed(itemWidth), spacing: itemSpacing), count: columnCount), spacing: 10) {
                                    ForEach(magicCards) { card in
                                        ZStack {
                                            MagicCardShopCardView(card: card)
                                                .frame(width: itemWidth)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(selectedCard?.id == card.id ? Color.orange : Color.clear, lineWidth: 2)
                                                )
                                            if !AppVersionManager.shared.checkMinimumVersion(card.version) {
                                                GeometryReader { geometry in
                                                    Text("不可用")
                                                        .font(.system(size: geometry.size.width * 0.2, weight: .bold))
                                                        .foregroundColor(.white)
                                                        .padding(geometry.size.width * 0.04)
                                                        .background(Color.red.opacity(0.5))
                                                        .cornerRadius(geometry.size.width * 0.04)
                                                }
                                            }
                                        }
                                        .onTapGesture {
                                            if selectedCard?.id == card.id {
                                                selectedCard = nil
                                            } else {
                                                selectedCard = card
                                            }
                                        }
                                    }
                                }
                                .padding(20)
                            }
                            .refreshable {
                                selectedCard = nil
                                await queryMagicCards(withLoadingToast: false)
                            }
                            if let card = selectedCard {
                                HStack(alignment: .bottom, spacing: 20) {
                                    VStack(alignment: .leading) {
                                        HStack {
                                            Text(card.name)
                                                .bold()
                                            if !AppVersionManager.shared.checkMinimumVersion(card.version) {
                                                Text("客户端版本过低，卡牌暂时无法使用")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.red)
                                            }
                                            Spacer()
                                            Image(systemName: card.ccasset_type.iconName)
                                            Text("\(card.price)")
                                        }
                                        .font(.system(size: 15))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 5)
                                        
                                        ScrollView {
                                            Text(card.description)
                                                .font(.system(size: 12))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(4)
                                        }
                                        .frame(height: 48)
                                        .padding(6)
                                        .background(Color.gray.opacity(0.8))
                                        .cornerRadius(10)
                                    }
                                    Text("购买")
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.orange)
                                        .cornerRadius(8)
                                        .onTapGesture {
                                            assetManager.purchaseMCWithCC(cardID: card.def_id)
                                        }
                                }
                                .padding()
                                .background(Color.black)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .background(Color.gray.opacity(0.2))
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onStableAppear {
            if firstOnAppear || globalConfig.refreshShopView {
                Task {
                    selectedAsset = nil
                    selectedCard = nil
                    await queryCPAssets(withLoadingToast: true)
                    await queryMagicCards(withLoadingToast: true)
                }
                globalConfig.refreshShopView  = false
            }
            firstOnAppear = false
        }
    }
    
    func queryCPAssets(withLoadingToast: Bool) async {
        DispatchQueue.main.async {
            cpassets.removeAll()
        }
        let request = APIRequest(path: "/asset/query_cpassets_on_shelves", method: .get, requiresAuth: true)
        
        let result = await NetworkService.sendAsyncRequest(with: request, decodingType: CPAssetShopResponse.self, showLoadingToast: withLoadingToast, showErrorToast: true)
        
        switch result {
        case .success(let data):
            if let unwrappedData = data {
                DispatchQueue.main.async {
                    for asset in unwrappedData.assets {
                        cpassets.append(CPAssetShopInfo(from: asset))
                    }
                }
            }
        default: break
        }
    }
    
    func queryMagicCards(withLoadingToast: Bool) async {
        DispatchQueue.main.async {
            magicCards.removeAll()
        }
        let request = APIRequest(path: "/asset/query_equip_cards_on_shelves", method: .get, requiresAuth: true)
        
        let result = await NetworkService.sendAsyncRequest(with: request, decodingType: MagicCardShopResponse.self, showLoadingToast: withLoadingToast, showErrorToast: true)
        
        switch result {
        case .success(let data):
            if let unwrappedData = data {
                DispatchQueue.main.async {
                    for card in unwrappedData.cards {
                        magicCards.append(MagicCardShop(from: card))
                    }
                }
            }
        default: break
        }
    }
}

struct AssetCounterView: View {
    let icon: String
    let amount: Int
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15))
            Text("\(amount)")
                .font(.headline)
        }
        .foregroundColor(.white)
    }
}

struct CPAssetShopCardView: View {
    let asset: CPAssetShopInfo
    
    var body: some View {
        VStack(spacing: 5) {
            CachedAsyncImage(
                urlString: asset.image_url,
                placeholder: Image("Ads"),
                errorImage: Image(systemName: "photo.badge.exclamationmark")
            )
            .aspectRatio(contentMode: .fit)
            .frame(height: 55)
            .clipped()
            
            HStack(spacing: 2) {
                Image(systemName: asset.ccassetType.iconName)
                Text("\(asset.price)")
            }
            .font(.caption2)
            .foregroundColor(.white)
            .padding(4)
            .frame(maxWidth: .infinity)
            .background(Color.orange)
            .cornerRadius(4)
            .frame(height: 25)
        }
        .frame(height: 80)
        .padding(8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
    }
}

struct MagicCardShopCardView: View {
    let card: MagicCardShop
    
    var body: some View {
        VStack(spacing: 15) {
            MagicCardView(card: MagicCard(withShopCard: card))
                //.frame(height: 120)
            
            HStack(spacing: 2) {
                Image(systemName: card.ccasset_type.iconName)
                Text("\(card.price)")
            }
            .font(.caption2)
            .foregroundColor(.white)
            .padding(4)
            .frame(maxWidth: .infinity)
            .background(Color.orange)
            .cornerRadius(4)
            .frame(height: 25)
        }
        //.frame(height: 145)
        .padding(10)
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
    }
}

#Preview {
    let appState = AppState.shared
    return ShopView()
        .environmentObject(appState)
}
