//
//  ShopView.swift
//  sportsx
//
//  Created by 任杰 on 2025/7/2.
//

import SwiftUI
import StoreKit


struct ShopView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var assetManager = AssetManager.shared
    @ObservedObject var shopManager = ShopManager.shared
    @State var selectedTab: Int = 0
    
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
                HStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.secondText)
                            .onTapGesture {
                                Task {
                                    await assetManager.queryCCAssets()
                                }
                            }
                        HStack(spacing: 4) {
                            AssetCounterView(icon: CCAssetType.coin.iconName, amount: assetManager.coin)
                            Button(action:{
                                PopupWindowManager.shared.presentPopup(
                                    bottomButtons: []
                                ) {
                                    CoinPurchaseView()
                                }
                            }) {
                                Image(systemName: "plus.rectangle.fill")
                                    .foregroundStyle(Color.white)
                                    .font(.system(size: 18))
                            }
                        }
                        AssetCounterView(icon: CCAssetType.voucher.iconName, amount: assetManager.voucher)
                        HStack(spacing: 4) {
                            AssetCounterView(icon: CCAssetType.coupon.iconName, amount: assetManager.coupon)
                            Button(action:{
                                guard UserManager.shared.isLoggedIn else {
                                    UserManager.shared.showingLogin = true
                                    return
                                }
                                appState.navigationManager.append(.iapCouponView)
                            }) {
                                Image(systemName: "plus.rectangle.fill")
                                    .foregroundStyle(Color.white)
                                    .font(.system(size: 18))
                            }
                        }
                    }
                }
                .padding(15)
                
                HStack(spacing: 0) {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            Text("shop.tab.props")
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
                            Text("shop.tab.equip_card")
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
                        let columnCount = 4
                        let totalSpacing = itemSpacing * CGFloat(columnCount - 1)
                        let itemWidth = (geo.size.width - totalSpacing - 20) / CGFloat(columnCount) // 20为ScrollView两侧padding
                        
                        ZStack(alignment: .bottom) {
                            ScrollView {
                                LazyVGrid(columns: Array(repeating: GridItem(.fixed(itemWidth), spacing: itemSpacing), count: columnCount), spacing: 10) {
                                    ForEach(shopManager.cpassets) { asset in
                                        CPAssetShopCardView(asset: asset)
                                            .frame(width: itemWidth)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(shopManager.selectedAsset?.id == asset.id ? Color.orange : Color.clear, lineWidth: 2)
                                            )
                                            .onTapGesture {
                                                if shopManager.selectedAsset?.id == asset.id {
                                                    shopManager.selectedAsset = nil
                                                } else {
                                                    shopManager.selectedAsset = CommonAssetShopInfo(from: asset)
                                                }
                                            }
                                    }
                                }
                                .padding(.top, 10)
                                .padding(.bottom, 100)
                            }
                            .refreshable {
                                await shopManager.queryCPAssets(withLoadingToast: false)
                            }
                        }
                    }
                    .tag(0)
                    
                    GeometryReader { geo in
                        let itemSpacing: CGFloat = 20
                        let columnCount = 3
                        let totalSpacing = itemSpacing * CGFloat(columnCount - 1)
                        let itemWidth = (geo.size.width - totalSpacing - 40) / CGFloat(columnCount) // 40为ScrollView两侧padding
                        
                        ZStack(alignment: .bottom) {
                            ScrollView {
                                LazyVGrid(columns: Array(repeating: GridItem(.fixed(itemWidth), spacing: itemSpacing), count: columnCount), spacing: 10) {
                                    ForEach(shopManager.magicCards) { card in
                                        ZStack {
                                            MagicCardShopCardView(card: card)
                                                .frame(width: itemWidth)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(shopManager.selectedAsset?.id == card.id ? Color.orange : Color.clear, lineWidth: 2)
                                                )
                                            /*if !AppVersionManager.shared.checkMinimumVersion(card.version) {
                                             GeometryReader { geometry in
                                             Text("warehouse.equipcard.unavailable")
                                             .font(.system(size: geometry.size.width * 0.2, weight: .bold))
                                             .foregroundColor(.white)
                                             .padding(geometry.size.width * 0.04)
                                             .background(Color.red.opacity(0.5))
                                             .cornerRadius(geometry.size.width * 0.04)
                                             }
                                             }*/
                                        }
                                        .onTapGesture {
                                            if shopManager.selectedAsset?.id == card.id {
                                                shopManager.selectedAsset = nil
                                            } else {
                                                shopManager.selectedAsset = CommonAssetShopInfo(from: card)
                                            }
                                        }
                                    }
                                }
                                .padding(.top, 20)
                                .padding(.bottom, 100)
                            }
                            .refreshable {
                                await shopManager.queryMagicCards(withLoadingToast: false)
                            }
                        }
                    }
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .background(Color.gray.opacity(0.2))
            }
            
            if let asset = shopManager.selectedAsset {
                HStack(alignment: .bottom, spacing: 20) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(asset.name)
                                .bold()
                            if let version = asset.version, !AppVersionManager.shared.checkMinimumVersion(version) {
                                Text("warehouse.equipcard.unavailable.detail")
                                    .font(.system(size: 13))
                                    .foregroundColor(.red)
                            }
                            Spacer()
                            Image(asset.ccassetType.iconName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20)
                            Text("\(asset.price)")
                        }
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        
                        ScrollView {
                            Text(asset.description)
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
                    Text("shop.action.buy")
                        .foregroundColor(.white)
                        .frame(height: 60)
                        .padding(.horizontal, 16)
                        .background(Color.orange)
                        .cornerRadius(8)
                        .exclusiveTouchTapGesture {
                            PopupWindowManager.shared.presentPopup(
                                title: "shop.action.buy",
                                bottomButtons: [
                                    .cancel(),
                                    .confirm {
                                        if asset.assetType == .cpasset {
                                            assetManager.purchaseCPWithCC(assetID: asset.asset_id, amount: 1)
                                        } else if asset.assetType == .magiccard {
                                            assetManager.purchaseMCWithCC(cardID: asset.asset_id)
                                        }
                                    }
                                ]
                            ) {
                                RichTextLabel(
                                    templateKey: "shop.popup.buy.cpasset",
                                    items:
                                        [
                                            ("MONEY", .image(asset.ccassetType.iconName, width: 20)),
                                            ("MONEY", .text(" * \(asset.price)")),
                                            ("ASSET", .text(asset.name))
                                        ]
                                )
                            }
                        }
                }
                .padding()
                .background(Color.black)
                .padding(.bottom, 85)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(edges: .bottom)
    }
}

struct CoinPurchaseView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var assetManager = AssetManager.shared
    
    @State var coinCount: Int = 10   // 10的倍数
    
    var body: some View {
        VStack(spacing: 20) {
            (Text("shop.action.buy") + Text("ccasset.coin"))
                .font(.title3.bold())
                .foregroundColor(.white)
            RichTextLabel(
                templateKey: "shop.popup.buy.ccasset.coin",
                items:
                    [
                        ("MONEY1", .image(CCAssetType.coupon.iconName, width: 20)),
                        ("MONEY2", .image(CCAssetType.voucher.iconName, width: 20)),
                        ("ASSET", .image(CCAssetType.coin.iconName, width: 20))
                    ]
            )
            if coinCount % 10 != 0 {
                Text("shop.popup.buy.coin.error.1")
                    .font(.caption)
                    .foregroundStyle(Color.pink)
            }
            if coinCount < 10 {
                Text("shop.popup.buy.coin.error.2")
                    .font(.caption)
                    .foregroundStyle(Color.pink)
            }
            HStack(spacing: 12) {
                TextField("0", value: $coinCount, formatter: NumberFormatter())
                    .keyboardType(.numberPad)
                    .foregroundColor(.white)
                    .font(.system(size: 20, weight: .semibold))
                    .padding(10)
                    .frame(height: 40)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                    .onValueChange(of: coinCount) {
                        if coinCount > 99999 {
                            coinCount = 99999
                        }
                    }
                HStack(spacing: 6) {
                    Button("+10") { coinCount += 10 }
                        .padding(.horizontal, 6)
                        .frame(height: 40)
                        .background(Color.black.opacity(0.25))
                        .cornerRadius(6)
                    Button("+100") { coinCount += 100 }
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
                                assetManager.purchaseCCWithCC(buy: .coin, amount: coinCount, use: .coupon)
                            }
                        ]
                    ) {
                        RichTextLabel(
                            templateKey: "shop.popup.buy.ccasset.confirm",
                            items:
                                [
                                    ("MONEY", .image(CCAssetType.coupon.iconName, width: 20)),
                                    ("MONEYCOUNT", .text("\(Int(coinCount / 10))")),
                                    ("ASSET", .image(CCAssetType.coin.iconName, width: 20)),
                                    ("ASSETCOUNT", .text("\(coinCount)"))
                                ]
                        )
                    }
                } label: {
                    HStack {
                        Image("coupon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20)
                        Text("\(Int(coinCount / 10))")
                            .foregroundStyle(Color.white)
                    }
                    .padding(10)
                    .background((coinCount % 10 == 0 && coinCount >= 10) ? Color.orange : Color.gray)
                    .cornerRadius(10)
                }
                .disabled(coinCount % 10 != 0 || coinCount < 10)
                Button {
                    _ = PopupWindowManager.shared.dismissPopup()
                    PopupWindowManager.shared.presentPopup(
                        title: "shop.action.buy",
                        bottomButtons: [
                            .cancel(),
                            .confirm {
                                assetManager.purchaseCCWithCC(buy: .coin, amount: coinCount, use: .voucher)
                            }
                        ]
                    ) {
                        RichTextLabel(
                            templateKey: "shop.popup.buy.ccasset.confirm",
                            items:
                                [
                                    ("MONEY", .image(CCAssetType.voucher.iconName, width: 20)),
                                    ("MONEYCOUNT", .text("\(Int(coinCount / 10))")),
                                    ("ASSET", .image(CCAssetType.coin.iconName, width: 20)),
                                    ("ASSETCOUNT", .text("\(coinCount)"))
                                ]
                        )
                    }
                } label: {
                    HStack {
                        Image("voucher")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20)
                        Text("\(Int(coinCount / 10))")
                            .foregroundStyle(Color.white)
                    }
                    .padding(10)
                    .background((coinCount % 10 == 0 && coinCount >= 10) ? Color.orange : Color.gray)
                    .cornerRadius(10)
                }
                .disabled(coinCount % 10 != 0 || coinCount < 10)
            }
        }
    }
}

struct AssetCounterView: View {
    let icon: String
    let amount: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 20)
            Text("\(amount)")
                .font(.headline)
        }
        .foregroundColor(.white)
    }
}

struct CPAssetShopCardView: View {
    let asset: CPAssetShopInfo
    
    var body: some View {
        VStack(spacing: 10) {
            CachedAsyncImage(
                urlString: asset.image_url
            )
            .aspectRatio(contentMode: .fit)
            .frame(height: 55)
            .clipped()
            
            HStack(spacing: 2) {
                Image(asset.ccassetType.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18)
                Text("\(asset.price)")
            }
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(4)
            .frame(maxWidth: .infinity)
            .background(Color.orange)
            .cornerRadius(4)
            .frame(height: 25)
        }
        .frame(height: 90)
        .padding(10)
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
    }
}

struct MagicCardShopCardView: View {
    let card: MagicCardShop
    
    var body: some View {
        VStack(spacing: 15) {
            MagicCardView(card: MagicCard(withShopCard: card), isShopCardView: true)
                //.frame(height: 120)
            
            HStack(spacing: 2) {
                Image(card.ccasset_type.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18)
                Text("\(card.price)")
            }
            .font(.system(size: 15, weight: .semibold, design: .rounded))
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

struct IAPCouponView: View {
    @ObservedObject var navigationManager = NavigationManager.shared
    @ObservedObject var assetManager = AssetManager.shared
    @ObservedObject private var iapManager = IAPManager.shared
    
    var body: some View {
        VStack(spacing: 30) {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal)
            VStack {
                HStack(alignment: .bottom) {
                    Text("iap.coupon.title")
                        .font(.title)
                    Spacer()
                    HStack(spacing: 0) {
                        Image("coupon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20)
                        Text("：\(assetManager.coupon)")
                    }
                }
                .foregroundStyle(Color.white)
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 20),
                        GridItem(.flexible(), spacing: 20),
                        GridItem(.flexible(), spacing: 20)
                    ],
                    spacing: 20
                ) {
                    ForEach(iapManager.couponProducts, id: \.id) { info in
                        CouponCardView(productInfo: info)
                        //.frame(height: 200)
                            .exclusiveTouchTapGesture {
                                Task {
                                    let progressToast = LoadingToast()
                                    DispatchQueue.main.async {
                                        ToastManager.shared.start(toast: progressToast)
                                    }
                                    await iapManager.purchaseCoupon(product: info.product)
                                    DispatchQueue.main.async {
                                        ToastManager.shared.finish()
                                    }
                                }
                            }
                    }
                }
                Spacer()
            }
            .padding()
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .onFirstAppear {
            Task {
                await iapManager.loadCouponProducts()
            }
        }
    }
}

struct CouponCardView: View {
    let iapManager = IAPManager.shared
    let productInfo: CouponProductInfo
    
    var body: some View {
        ZStack(alignment: .top) {
            let bg = iapManager.couponImages[productInfo.product.id] ?? "coupon"
            Image("coupon_background")
                .resizable()
                .scaledToFit()
                .clipped()
            VStack(spacing: 0) {
                Image(bg)
                    .resizable()
                    .scaledToFit()
                    .clipped()
                HStack(spacing: 2) {
                    Text("\(productInfo.count)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.green)
                    if let gift = productInfo.count_gift {
                        Text("+\(gift)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.pink)
                    }
                }
                .padding(.vertical, 5)
                Text(productInfo.product.displayPrice)
                    .padding(.vertical, 8)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(Color.white)
                    .background(Color.orange)
            }
        }
    }
}

#Preview {
    let appState = AppState.shared
    return ShopView()
        .environmentObject(appState)
}
