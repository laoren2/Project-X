//
//  KeyChainHelper.swift
//  sportsx
//
//  专为存储敏感信息如 Token 而设计，可用于生产环境
//
//  Created by 任杰 on 2025/5/15.
//
import Foundation
import Security


final class KeychainHelper {
    static let standard = KeychainHelper()
    private init() {}

    // DID
    var deviceID: String? = nil
    
    // 身份 token
    var token: String? = nil
    
    func saveToken(_ value: String) {
        save(value, forKey: "access_token")
        token = value
    }
    
    func deleteToken() {
        delete(forKey: "access_token")
        token = nil
    }
    
    func loadToken() -> Bool {
        if let value = read(forKey: "access_token") {
            token = value
            return true
        }
        return false
    }
    
    /// 保存字符串到 Keychain
    func save(_ value: String, forKey key: String) {
        if let data = value.data(using: .utf8) {
            save(data, forKey: key)
        }
        //print("save token success")
    }

    /// 读取字符串
    func read(forKey key: String) -> String? {
        if let data = readData(forKey: key) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    /// 删除指定 key
    func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        //print("delete token success")
    }

    /// 保存 Data 到 Keychain
    func save(_ data: Data, forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        // 如果已存在则更新
        if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: data
            ]
            SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        } else {
            // 否则添加
            var newQuery = query
            newQuery[kSecValueData as String] = data
            SecItemAdd(newQuery as CFDictionary, nil)
        }
    }

    /// 读取 Data
    func readData(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess {
            return result as? Data
        }
        return nil
    }
    
    func loadDeviceID() async {
        if let DID = KeychainHelper.standard.read(forKey: "device_id") {
            // save to local
            deviceID = DID
        } else {
            // 服务端生成
            if let newDID = await generate_15bits_did() {
                deviceID = newDID
                KeychainHelper.standard.save(newDID, forKey: "device_id")
            } else {
                print("DID generate failed")
            }
        }
    }
    
    func generate_15bits_did() async -> String? {
        guard var components = URLComponents(string: "/common/generate_did") else { return nil }
        guard let urlPath = components.url?.absoluteString else { return nil }
        
        let request = APIRequest(path: urlPath, method: .post)
        let result = await NetworkService.sendAsyncRequest(with: request, decodingType: String.self, showErrorToast: true)
        switch result {
        case .success(let data):
            return data
        default: break
        }
        return nil
    }
}
