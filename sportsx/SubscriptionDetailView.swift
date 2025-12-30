//
//  SubscriptionDetailView.swift
//  sportsx
//
//  Created by 任杰 on 2025/12/4.
//

import SwiftUI
import StoreKit
import PhotosUI


struct SubscriptionDetailView: View {
    @ObservedObject var navigationManager = NavigationManager.shared
    @ObservedObject var userManager = UserManager.shared
    @State private var selectedProduct: Product? = nil
    @State private var isSubscribed: Bool = false
    @State private var autoRenew: Bool?
    @State private var startDate: Date?
    @State private var expireDate: Date?
    @State private var isLoading: Bool = true
    
    @State private var webPage: WebPage?
    @State private var agreed = false
    
    @ObservedObject private var manager = IAPManager.shared
    
    var body: some View {
        VStack {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                Spacer()
                Text("iap.subscription.vip_center")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.clear)
                }
            }
            .padding(.horizontal)
            ZStack(alignment: .bottom) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 10) {
                                    if let avatar = userManager.avatarImage {
                                        Image(uiImage: avatar)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 30, height: 30)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 30, height: 30)
                                            .foregroundStyle(.gray)
                                            .clipShape(Circle())
                                    }
                                    Text(isSubscribed ? "iap.subscription.vip_status.on" : "iap.subscription.vip_status.off")
                                        .font(.headline.bold())
                                        .foregroundStyle(isSubscribed ? .green : .thirdText)
                                    Spacer()
                                    Button(action:{
                                        updateSubscriptionStatus(enforce: true)
                                    }) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 15))
                                            .foregroundStyle(Color.thirdText)
                                    }
                                }
                                if let start = startDate {
                                    HStack(spacing: 0) {
                                        Text("iap.subscription.vip_date.from")
                                        Text(LocalizedStringKey(DateDisplay.formattedDate(start)))
                                    }
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                }
                                if let end = expireDate {
                                    HStack(spacing: 0) {
                                        Text("iap.subscription.vip_date.to")
                                        Text(LocalizedStringKey(DateDisplay.formattedDate(end)))
                                    }
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                }
                                if let autoStatus = autoRenew {
                                    HStack(spacing: 0) {
                                        Text("iap.subscription.auto_renewable")
                                        Text(autoStatus ? "iap.subscription.auto_renewable.on" : "iap.subscription.auto_renewable.off")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                }
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        
                        subscriptionCards
                        
                        VStack(alignment: .leading) {
                            Text("iap.subscription.benefits")
                                .font(.title3.bold())
                                .foregroundStyle(Color.white)
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 20) {
                                    Image("single_app_icon")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                    Text("iap.subscription.benefits.1")
                                }
                                Divider()
                                HStack(spacing: 20) {
                                    Image("single_app_icon")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                    Text("iap.subscription.benefits.2")
                                }
                                Divider()
                                HStack(spacing: 20) {
                                    Image("single_app_icon")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                    Text("iap.subscription.benefits.3")
                                }
                            }
                            .foregroundStyle(Color.secondText)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 200)
                }
                
                VStack(spacing: 10) {
                    subscribeButton
                    HStack {
                        Spacer()
                        HStack(spacing: 5) {
                            Image(systemName: agreed ? "checkmark.circle" : "circle")
                                .frame(width: 15, height: 15)
                                .foregroundStyle(agreed ? Color.orange : Color.secondText)
                                .onTapGesture {
                                    agreed.toggle()
                                }
                            Text("action.read_and_agree")
                            Text("iap.subscription.action.vip_autorenewal_agreement")
                                .underline()
                                .foregroundStyle(Color.orange.opacity(0.6))
                                .onTapGesture {
                                    AgreementHelper.open("https://www.valbara.top/subscription_agreement", binding: $webPage)
                                }
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(Color.thirdText)
                        .sheet(item: $webPage) { item in
                            SafariView(url: item.url)
                                .ignoresSafeArea()
                        }
                        Spacer()
                        Button(action:{
                            navigationManager.append(.iapHelpView)
                        }) {
                            Text("iap.subscription.action.help")
                                .padding(.vertical, 10)
                                .padding(.horizontal, 15)
                                .foregroundStyle(Color.white)
                                .background(Color.gray.opacity(0.6))
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(.bottom, 20)
                .padding(.top, 10)
                .padding(.horizontal)
                .background(Color.defaultBackground)
            }
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .onFirstAppear {
            Task {
                await manager.loadSubscriptionProducts()
                DispatchQueue.main.async {
                    if !manager.subscriptionProducts.isEmpty {
                        selectedProduct = manager.subscriptionProducts[0]
                    }
                }
            }
            updateSubscriptionStatus()
        }
    }
    
    func updateSubscriptionStatus(enforce: Bool = false) {
        guard var components = URLComponents(string: "/iap/query_subscription_status") else { return }
        components.queryItems = [
            URLQueryItem(name: "enforce", value: "\(enforce)")
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: IAPSubscriptionInfoResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        isSubscribed = unwrappedData.is_active
                        UserManager.shared.user.isVip = unwrappedData.is_active
                        if let autoStatus = unwrappedData.auto_renew, let start = unwrappedData.started_at, let end = unwrappedData.expired_at {
                            autoRenew = autoStatus
                            startDate = ISO8601DateFormatter().date(from: start)
                            expireDate = ISO8601DateFormatter().date(from: end)
                        }
                    }
                }
            default: break
            }
        }
    }
}

// MARK: - 子视图拆分
extension SubscriptionDetailView {
    // 4 个订阅卡片区域
    private var subscriptionCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(manager.subscriptionProducts, id: \.id) { product in
                    SubscriptionCardView(
                        product: product,
                        isSelected: selectedProduct?.id == product.id
                    )
                    .onTapGesture {
                        selectedProduct = product
                    }
                }
            }
            .padding(4)
        }
    }
    
    // 订阅按钮
    private var subscribeButton: some View {
        Button {
            guard agreed else {
                ToastManager.shared.show(toast: Toast(message: "iap.subscription.toast.vip_autorenewal_agreement"))
                return
            }
            Task {
                guard let product = selectedProduct else { return }
                if isSubscribed {
                    if let text = await manager.checkPurchasedSubscription(product: product) {
                        DispatchQueue.main.async {
                            ToastManager.shared.show(toast: Toast(message: text, duration: 3))
                        }
                        return
                    }
                } else {
                    guard !(await manager.checkAllPurchasedSubscriptions()) else {
                        DispatchQueue.main.async {
                            ToastManager.shared.show(toast: Toast(message: "iap.subscription.toast.purchase.failed.sub_off", duration: 3))
                        }
                        return
                    }
                }
                let progressToast = LoadingToast()
                DispatchQueue.main.async {
                    ToastManager.shared.start(toast: progressToast)
                }
                if let subInfo = await manager.purchaseSubscription(product: product) {
                    DispatchQueue.main.async {
                        isSubscribed = subInfo.isActive
                        autoRenew = subInfo.autoRenew
                        if let start = subInfo.startDate, let end = subInfo.expireDate {
                            DispatchQueue.main.async {
                                startDate = ISO8601DateFormatter().date(from: start)
                                expireDate = ISO8601DateFormatter().date(from: end)
                            }
                        }
                    }
                    // 更新用户的订阅状态 & original_transaction_id
                    await UserManager.shared.fetchMeInfo()
                }
                DispatchQueue.main.async {
                    ToastManager.shared.finish()
                }
            }
        } label: {
            Text(isSubscribed ? "iap.subscription.action.update_purchase" : "iap.subscription.action.purchase")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.vertical)
                .frame(maxWidth: .infinity)
                .background(isSubscribed ? Color.green : Color.orange)
                .cornerRadius(10)
        }
        .disabled(selectedProduct == nil)
    }
}

struct SubscriptionCardView: View {
    let product: Product
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text(product.displayName)
                .font(.headline)
                .foregroundStyle(isSelected ? Color.white : Color.thirdText)
                .fixedSize(horizontal: false, vertical: true)
            Text(product.description)
                .font(.subheadline)
                .foregroundStyle(isSelected ? Color.secondText : Color.thirdText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            // 显示平均到每天的价格
            if let dailyPriceText = dailyPriceText {
                Text(dailyPriceText)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? Color.white : Color.thirdText)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(isSelected ? Color.orange.opacity(0.8) : Color.orange.opacity(0.2))
                    .cornerRadius(8)
            }
            Text(product.displayPrice)
                .font(isSelected ? .headline: .subheadline)
                .foregroundStyle(isSelected ? Color.white : Color.thirdText)
        }
        .frame(width: 160, height: 240)
        .padding()
        .background(isSelected ? Color.orange.opacity(0.2) : Color.gray.opacity(0.2))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
        )
    }

    // 计算每天的价格文本，例如："¥1.23 / 天"
    private var dailyPriceText: LocalizedStringKey? {
        guard let period = product.subscription?.subscriptionPeriod else {
            return nil
        }
        
        let totalDays = periodTotalDays(period)
        guard totalDays > 0 else { return nil }
        
        let dailyPrice = product.price / Decimal(totalDays)

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = product.priceFormatStyle.currencyCode
        formatter.maximumFractionDigits = 2

        let number = dailyPrice as NSDecimalNumber
        guard let formatted = formatter.string(from: number) else { return nil }

        return "time.per_day \(formatted)"
    }

    // 将订阅周期统一转换为“天”
    private func periodTotalDays(_ period: Product.SubscriptionPeriod) -> Int {
        switch period.unit {
        case .day:
            return period.value
        case .week:
            return period.value * 7
        case .month:
            return period.value * 30
        case .year:
            return period.value * 365
        @unknown default:
            return 0
        }
    }
}

struct IAPHelpView: View {
    @ObservedObject var navigationManager = NavigationManager.shared
    
    var body: some View {
        VStack(spacing: 40) {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                Spacer()
                Text("iap.subscription.action.help")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.clear)
                Spacer()
                Button(action: {
                    navigationManager.append(.feedbackView(mailType: .iap))
                }) {
                    Text("action.feedback")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.white)
                }
            }
            JustifiedText("iap.subscription.help_prompts", textColor: UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1))
                //.border(.red)
                
            Button(action:{
                Task {
                    await IAPManager.shared.queryEntitlementAccount()
                }
            }) {
                Text("action.click_and_query")
                    .padding(.vertical)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
    }
}

#Preview {
    return IAPHelpView()
}
