//
//  CurrencyManager.swift
//  sportsx
//
//  集中管理虚拟货币的充值提现与消费
//
//  Created by 任杰 on 2025/3/13.
//

import Foundation


class CurrencyManager: ObservableObject {
    @Published var coinA: Int = 1000
    @Published var coinB: Int = 10000
    
    static let shared = CurrencyManager()
    
    private init() {}
    
    func fetchBalance() {
        // 调用 API 获取最新余额
    }
    
    func recharge(amount: Int) {
        // 处理充值请求，成功后更新coin
    }
    
    func withdraw(amount: Int) {
        // 处理提现请求
    }
    
    func reward(currency: String, amount: Int) {
        switch currency {
        case "coinA":
            coinA += amount
             
        case "coinB":
            coinB += amount
            
        default:
            break
        }
    }

    func consume(currency: String, amount: Int) -> Bool {
        // 先检查余额是否足够，足够则更新余额
        switch currency {
        case "coinA":
            if coinA >= amount {
                coinA -= amount
                return true
            }
        case "coinB":
            if coinB >= amount {
                coinB -= amount
                return true
            }
        default:
            break
        }
        return false
    }
}
