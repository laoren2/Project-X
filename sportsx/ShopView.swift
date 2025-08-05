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
    @State var selectedAsset: CPAssetShopInfo? = nil
    @State var selectedTab: Int = 0
    @State private var firstOnAppear = true
    let globalConfig = GlobalConfig.shared
    
    
    var body: some View {
        ZStack(alignment: .bottom) {
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
                    }
                    .frame(maxHeight: .infinity)
                    .refreshable {
                        selectedAsset = nil
                        await fetchCPAssets(withLoadingToast: false)
                    }
                    .background(Color.gray.opacity(0.2))
                    .tag(0)
                    
                    GeometryReader { geo in
                        let itemSpacing: CGFloat = 20
                        let columnCount = 3
                        let totalSpacing = itemSpacing * CGFloat(columnCount - 1)
                        let itemWidth = (geo.size.width - totalSpacing - 40) / CGFloat(columnCount) // 40为ScrollView两侧padding

                        ScrollView {
                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(itemWidth), spacing: itemSpacing), count: columnCount), spacing: 10) {
                                // todo
                            }
                            .padding(20)
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .refreshable {
                        //await fetchCPAssets(withLoadingToast: false)
                    }
                    .background(Color.gray.opacity(0.2))
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
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
        .toolbar(.hidden, for: .navigationBar)
        .onStableAppear {
            if firstOnAppear || globalConfig.refreshShopView {
                assetManager.queryCCAssets()
                Task {
                    selectedAsset = nil
                    await fetchCPAssets(withLoadingToast: true)
                }
                globalConfig.refreshShopView  = false
            }
            firstOnAppear = false
        }
    }
    
    func fetchCPAssets(withLoadingToast: Bool) async {
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

#Preview {
    let appState = AppState.shared
    return ShopView()
        .environmentObject(appState)
}
