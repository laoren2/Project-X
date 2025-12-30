//
//  IAPManager.swift
//  sportsx
//
//  Created by 任杰 on 2025/12/2.
//

import Foundation
import StoreKit
import SwiftUI


class IAPManager: ObservableObject {
    static let shared = IAPManager()
    
    private init() {
        updates = newTransactionListenerTask()
    }
    
    let userManager = UserManager.shared
    
    // product IDs
    let couponProductIDs: [String] = [
        "com.valbara.sporreer.coupon.10",
        "com.valbara.sporreer.coupon.80",
        "com.valbara.sporreer.coupon.180",
        "com.valbara.sporreer.coupon.380",
        "com.valbara.sporreer.coupon.680",
        "com.valbara.sporreer.coupon.1280"
    ]
    
    let subscriptionProductIDs: [String] = [
        "com.valbara.sporreer.subscription.1m.auto",
        "com.valbara.sporreer.subscription.3m.auto",
        "com.valbara.sporreer.subscription.6m.auto",
        "com.valbara.sporreer.subscription.1y.auto"
    ]
    
    let couponImages: [String: String] = [
        "com.valbara.sporreer.coupon.10": "10_coupons",
        "com.valbara.sporreer.coupon.80": "80_coupons",
        "com.valbara.sporreer.coupon.180": "180_coupons",
        "com.valbara.sporreer.coupon.380": "380_coupons",
        "com.valbara.sporreer.coupon.680": "680_coupons",
        "com.valbara.sporreer.coupon.1280": "1280_coupons"
    ]
    
    var updates: Task<Void, Never>? = nil
    
    // 已加载产品
    @Published var couponProducts: [CouponProductInfo] = []
    @Published var subscriptionProducts: [Product] = []
    
    // 初始化 /请求 product 列表
    func loadSubscriptionProducts() async {
        guard subscriptionProducts.isEmpty else { return }
        do {
            let products = try await Product.products(for: Set(subscriptionProductIDs))
            let sortedProducts = products.sorted { a, b in
                guard
                    let ia = subscriptionProductIDs.firstIndex(of: a.id),
                    let ib = subscriptionProductIDs.firstIndex(of: b.id)
                else { return false }
                return ia < ib
            }
            await MainActor.run {
                subscriptionProducts = sortedProducts
            }
        } catch {
            print("abnormal catched in subscription products loading...")
        }
    }
    
    func loadCouponProducts() async {
        guard couponProducts.isEmpty else { return }
        do {
            let products = try await Product.products(for: Set(couponProductIDs))
            let sortedProducts = products.sorted { a, b in
                guard
                    let ia = couponProductIDs.firstIndex(of: a.id),
                    let ib = couponProductIDs.firstIndex(of: b.id)
                else { return false }
                return ia < ib
            }
            
            if let couponResponse = await queryCouponShopInfos() {
                var shopMap: [String: CouponProductShopInfo] = [:]
                for item in couponResponse.coupons {
                    // 后面的会覆盖前面的，不会崩溃
                    shopMap[item.product_id] = item
                }
                let shopInfos: [CouponProductInfo] = sortedProducts.compactMap { product in
                    guard let shopInfo = shopMap[product.id] else { return nil }
                    return CouponProductInfo(
                        product: product,
                        count: shopInfo.coupon,
                        count_gift: shopInfo.coupon_gift
                    )
                }
                await MainActor.run {
                    couponProducts = shopInfos
                }
            }
        } catch {
            print("点券信息加载失败")
        }
    }
    
    // 查询点券商店信息
    func queryCouponShopInfos() async -> CouponProductShopResponse? {
        let request = APIRequest(path: "/iap/query_coupon_infos", method: .get, requiresAuth: true)
        
        let result = await NetworkService.sendAsyncRequest(with: request, decodingType: CouponProductShopResponse.self, showErrorToast: true)
        
        switch result {
        case .success(let data):
            if let unwrappedData = data {
                return unwrappedData
            }
        default: break
        }
        return nil
    }
    
    // 购买点券
    func purchaseCoupon(product: Product) async {
        do {
            guard let token = UUID(uuidString: userManager.user.appleIAPToken) else {
                DispatchQueue.main.async {
                    ToastManager.shared.show(toast: Toast(message: "iap.coupon.failed"))
                }
                return
            }
            let purchaseOption = Product.PurchaseOption.appAccountToken(token)
            let result = try await product.purchase(options: [purchaseOption])
            switch result {
            case .success(let verificationResult):
                switch verificationResult {
                case .verified(let transaction):
                    // 发送到服务器进行验证 & 更新权益
                    if let coupon = await verifyCouponPurchase(payload: String(verificationResult.jwsRepresentation)) {
                        DispatchQueue.main.async {
                            AssetManager.shared.coupon = coupon
                            ToastManager.shared.show(toast: Toast(message: "iap.coupon.success"))
                        }
                    }
                    await transaction.finish()
                case .unverified:
                    DispatchQueue.main.async {
                        ToastManager.shared.show(toast: Toast(message: "iap.coupon.failed"))
                    }
                }
            case .userCancelled:
                DispatchQueue.main.async {
                    ToastManager.shared.show(toast: Toast(message: "iap.coupon.cancel"))
                }
            case .pending:
                DispatchQueue.main.async {
                    ToastManager.shared.show(toast: Toast(message: "iap.coupon.pendding"))
                }
            @unknown default:
                DispatchQueue.main.async {
                    ToastManager.shared.show(toast: Toast(message: "iap.coupon.failed"))
                }
            }
        } catch {
            DispatchQueue.main.async {
                ToastManager.shared.show(toast: Toast(message: "iap.coupon.failed"))
            }
        }
    }
    
    func verifyCouponPurchase(payload: String) async -> Int? {
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        
        let body: [String: String] = [
            "jws": payload
        ]
        guard let encodedBody = try? JSONEncoder().encode(body) else {
            return nil
        }
        
        let request = APIRequest(path: "/iap/verify_coupon_transaction", method: .post, headers: headers, body: encodedBody, requiresAuth: true)
        let result = await NetworkService.sendAsyncRequest(with: request, decodingType: Int.self, showErrorToast: true)
        
        switch result {
        case .success(let data):
            if let unwrappedData = data {
                return unwrappedData
            }
        default: break
        }
        return nil
    }
    
    // 购买订阅
    func purchaseSubscription(product: Product) async -> SubscriptionInfo? {
        do {
            for await unfinish_result in Transaction.unfinished {
                if case .verified(let tran) = unfinish_result {
                    await tran.finish()
                }
            }
            guard let token = UUID(uuidString: userManager.user.appleIAPToken) else { return nil }
            let purchaseOption = Product.PurchaseOption.appAccountToken(token)
            let result = try await product.purchase(options: [purchaseOption])
            switch result {
            case .success(let verificationResult):
                switch verificationResult {
                case .verified(let transaction):
                    // 发送到服务器进行验证 & 更新权益
                    let verifyResult = await verifySubscriptionPurchase(payload: String(transaction.originalID))
                    if verifyResult.isActive {
                        DispatchQueue.main.async {
                            ToastManager.shared.show(toast: Toast(message: "iap.subscription.success"))
                        }
                    }
                    await transaction.finish()
                    return verifyResult
                case .unverified:
                    DispatchQueue.main.async {
                        ToastManager.shared.show(toast: Toast(message: "iap.subscription.failed"))
                    }
                }
            case .userCancelled:
                DispatchQueue.main.async {
                    ToastManager.shared.show(toast: Toast(message: "iap.subscription.cancel"))
                }
            case .pending:
                DispatchQueue.main.async {
                    ToastManager.shared.show(toast: Toast(message: "iap.subscription.pendding"))
                }
            @unknown default:
                DispatchQueue.main.async {
                    ToastManager.shared.show(toast: Toast(message: "iap.subscription.failed"))
                }
            }
        } catch {
            DispatchQueue.main.async {
                ToastManager.shared.show(toast: Toast(message: "iap.subscription.failed"))
            }
        }
        return nil
    }
    
    func verifySubscriptionPurchase(payload: String) async -> SubscriptionInfo {
        var subInfo = SubscriptionInfo(isActive: false)
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        
        let body: [String: String] = [
            "transaction_id": payload
        ]
        guard let encodedBody = try? JSONEncoder().encode(body) else {
            return subInfo
        }
        
        let request = APIRequest(path: "/iap/verify_auto_subscription_transaction", method: .post, headers: headers, body: encodedBody, requiresAuth: true)
        let result = await NetworkService.sendAsyncRequest(with: request, decodingType: IAPSubscriptionInfoResponse.self, showErrorToast: true)
        
        switch result {
        case .success(let data):
            if let unwrappedData = data {
                subInfo.isActive = unwrappedData.is_active
                subInfo.autoRenew = unwrappedData.auto_renew
                subInfo.startDate = unwrappedData.started_at
                subInfo.expireDate = unwrappedData.expired_at
                return subInfo
            }
        default: break
        }
        return subInfo
    }
    
    // 已订阅状态下的检查
    func checkPurchasedSubscription(product: Product) async -> String? {
        var entitlementsCnt = 0
        for await verificationResult in Transaction.currentEntitlements {
            switch verificationResult {
            case .verified(let transaction):
                if let subInfo = await transaction.subscriptionStatus {
                    entitlementsCnt += 1
                    if String(transaction.originalID) != userManager.originTransactionID {
                        return "iap.subscription.toast.purchase.failed.sub_on"
                    }
                    if transaction.productID == product.id, subInfo.state == .subscribed || subInfo.state == .inGracePeriod {
                        return "iap.subscription.toast.purchase.failed.reapeat_sub"
                    }
                }
            case .unverified:
                print("unverified purchased product check")
            }
        }
        if entitlementsCnt == 0 {
            return "iap.subscription.toast.purchase.failed.sub_on"
        }
        return nil
    }
    
    // 未订阅状态下的检查
    func checkAllPurchasedSubscriptions() async -> Bool {
        // 双重保险，尽量避免用户在不同账号修改另一个账号的订阅状态
        guard !subscriptionProducts.isEmpty else { return false }
        do {
            guard let allStatus = try await subscriptionProducts[0].subscription?.status else { return false }
            for status in allStatus {
                if status.state == .subscribed || status.state == .inGracePeriod {
                    return true
                }
            }
        } catch {
            print("catch error in checkAllPurchasedSubscriptions")
        }
        for await verificationResult in Transaction.currentEntitlements {
            switch verificationResult {
            case .verified(let transaction):
                for productID in subscriptionProductIDs {
                    if transaction.productID == productID, let status = await transaction.subscriptionStatus?.state, status == .subscribed || status == .inGracePeriod {
                        return true
                    }
                }
            case .unverified:
                print("unverified purchased product check")
            }
        }
        return false
    }
    
    private func newTransactionListenerTask() -> Task<Void, Never> {
        Task(priority: .background) {
            for await verificationResult in Transaction.updates {
                await self.handle(updatedTransaction: verificationResult)
            }
        }
    }
    
    // 这里只简单 finish 交易，所有权益交给服务端验证和查询
    private func handle(updatedTransaction verificationResult: VerificationResult<StoreKit.Transaction>) async {
        if case .verified(let transaction) = verificationResult {
            //print("new transaction update...")
            await transaction.finish()
        }
    }
    
    func queryEntitlementAccount() async {
        for await verificationResult in Transaction.currentEntitlements {
            switch verificationResult {
            case .verified(let transaction):
                if let status = await transaction.subscriptionStatus {
                    let nickName = await fetchAccountNicName(transactionID: String(transaction.originalID))
                    if let name = nickName {
                        DispatchQueue.main.async {
                            PopupWindowManager.shared.presentPopup(
                                title: "iap.subscription.toast.help.query.success.title",
                                bottomButtons: [
                                    .confirm("action.confirm")
                                ]
                            ) {
                                VStack {
                                    Text("iap.subscription.toast.help.query.success.content")
                                    Text(name)
                                }
                                .foregroundStyle(Color.white)
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            ToastManager.shared.show(toast: Toast(message: "iap.subscription.toast.help.query.failed", duration: 3))
                        }
                    }
                    return
                }
            default: break
            }
        }
        DispatchQueue.main.async {
            ToastManager.shared.show(toast: Toast(message: "iap.subscription.toast.help.query.failed", duration: 3))
        }
    }
    
    func fetchAccountNicName(transactionID: String) async -> String? {
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        
        let body: [String: String] = [
            "transaction_id": transactionID
        ]
        guard let encodedBody = try? JSONEncoder().encode(body) else {
            return nil
        }
        
        let request = APIRequest(path: "/iap/query_subscription_account", method: .post, headers: headers, body: encodedBody, requiresAuth: true)
        let result = await NetworkService.sendAsyncRequest(with: request, decodingType: String?.self, showLoadingToast: true, showErrorToast: true)
        
        switch result {
        case .success(let data):
            if let unwrappedData = data {
                return unwrappedData
            }
        default: break
        }
        return nil
    }
}

struct SubscriptionInfo: Codable {
    var isActive: Bool
    var autoRenew: Bool?
    var startDate: String?
    var expireDate: String?
}

struct IAPSubscriptionInfoResponse: Codable {
    let is_active: Bool
    let auto_renew: Bool?
    let started_at: String?
    let expired_at: String?
}

struct CouponProductInfo: Identifiable {
    var id: String { product.id }
    let product: Product
    let count: Int
    let count_gift: Int?
}

struct CouponProductShopInfo: Codable {
    let product_id: String
    let coupon: Int
    let coupon_gift: Int?
}

struct CouponProductShopResponse: Codable {
    let coupons: [CouponProductShopInfo]
}
