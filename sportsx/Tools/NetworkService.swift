//
//  NetworkService.swift
//  sportsx
//
//  Created by 任杰 on 2025/5/13.
//
import Foundation
import UIKit

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

enum APIError: Error {
    case networkError
    case httpError(status: Int)
    case businessError(code: Int, message: String)
    case decodeError
    case noData
    case unknown
}

struct APIRequest {
    var path: String
    var method: HTTPMethod
    var headers: [String: String]?
    var body: Data?
    var requiresAuth: Bool = false
    var isInternal: Bool = false
    var cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
}

struct APIResponse<T: Decodable>: Decodable {
    let access_token: String?
    let code: Int
    let message: String
    let data: T?
}

struct EmptyResponse: Decodable {}


struct NetworkService {
    static let baseDomain: String = "https://192.168.0.109:8000"
    static let baseUrl: String = "https://192.168.0.109:8000/api/v1"
    static let baseUrl_internal: String = "https://192.168.0.109:8000/api/internal"
    
    static func sendRequest<T: Decodable>(
        with apiRequest: APIRequest,
        decodingType: T.Type,
        showLoadingToast: Bool = false,
        showSuccessToast: Bool = false,
        showErrorToast: Bool = false,
        customErrorToast: ((APIError) -> Toast?)? = nil,
        completion: @escaping (Result<T?, APIError>) -> Void
    ) {
        // request
        let urlString = (apiRequest.isInternal ? baseUrl_internal : baseUrl) + apiRequest.path
        guard let url = URL(string: urlString) else {
            let toast = Toast(message: "URL无效", duration: 2)
            ToastManager.shared.show(toast: toast)
            return
        }
        
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = apiRequest.method.rawValue
        
        // Headers
        var allHeaders = apiRequest.headers ?? [:]
        if (apiRequest.requiresAuth || apiRequest.isInternal), let token = KeychainHelper.standard.read(forKey: "access_token") {
            allHeaders["Authorization"] = "Bearer \(token)"
        }
        for (key, value) in allHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Body
        if let body = apiRequest.body, apiRequest.method != .get {
            request.httpBody = body
        }
        request.cachePolicy = apiRequest.cachePolicy
        
        // 加载toast
        if showLoadingToast {
            let progressToast = LoadingToast()
            DispatchQueue.main.async {
                ToastManager.shared.start(toast: progressToast)
            }
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // 加载图标消失
            if showLoadingToast {
                DispatchQueue.main.async {
                    ToastManager.shared.finish()
                }
            }
            // 检查网络错误
            if error != nil {
                let toast = customErrorToast?(.networkError) ?? Toast(message: "网络错误", duration: 2)
                if showErrorToast {
                    DispatchQueue.main.async {
                        ToastManager.shared.show(toast: toast)
                    }
                }
                completion(.failure(.networkError))
                return
            }
            
            // 检查 HTTP 状态码
            guard let httpResponse = response as? HTTPURLResponse else {
                let toast = customErrorToast?(.unknown) ?? Toast(message: "未知错误", duration: 2)
                if showErrorToast {
                    DispatchQueue.main.async {
                        ToastManager.shared.show(toast: toast)
                    }
                }
                completion(.failure(.unknown))
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                var toast = Toast(message: "服务错误:\(httpResponse.statusCode)", duration: 2)
                if httpResponse.statusCode == 401 {
                    toast.message = "请先登录"
                    DispatchQueue.main.async {
                        UserManager.shared.showingLogin = true
                    }
                }
                if let customToast = customErrorToast?(.httpError(status: httpResponse.statusCode)) {
                    toast = customToast
                }
                if showErrorToast {
                    DispatchQueue.main.async {
                        ToastManager.shared.show(toast: toast)
                    }
                }
                completion(.failure(.httpError(status: httpResponse.statusCode)))
                return
            }
            
            // 解析 JSON
            guard let data = data else {
                let toast = customErrorToast?(.noData) ?? Toast(message: "数据错误", duration: 2)
                if showErrorToast {
                    DispatchQueue.main.async {
                        ToastManager.shared.show(toast: toast)
                    }
                }
                completion(.failure(.noData))
                return
            }
            
            guard let decoded = try? JSONDecoder().decode(APIResponse<T>.self, from: data) else {
                let toast = customErrorToast?(.decodeError) ?? Toast(message: "数据错误2", duration: 2)
                if showErrorToast {
                    DispatchQueue.main.async {
                        ToastManager.shared.show(toast: toast)
                    }
                }
                completion(.failure(.decodeError))
                return
            }
            
            if let token = decoded.access_token {
                KeychainHelper.standard.save(token, forKey: "access_token")
                print("save token: \(token) to Keychain")
            }
            
            // 判断业务 code
            if decoded.code == 0 {
                // 默认展示服务端传回的msg
                if showSuccessToast {
                    let toast = Toast(message: decoded.message, duration: 2)
                    DispatchQueue.main.async {
                        ToastManager.shared.show(toast: toast)
                    }
                }
                completion(.success(decoded.data))
            } else {
                let toast = customErrorToast?(.businessError(code: decoded.code, message: decoded.message)) ?? Toast(message: "\(decoded.message)", duration: 2)
                if showErrorToast {
                    DispatchQueue.main.async {
                        ToastManager.shared.show(toast: toast)
                    }
                }
                switch decoded.code {
                case 2006, 2007, 3002, 3003:
                    DispatchQueue.main.async {
                        UserManager.shared.showingLogin = true
                        UserManager.shared.logoutUser()
                        NavigationManager.shared.backToHome()
                    }
                default: break
                }
                completion(.failure(.businessError(code: decoded.code, message: decoded.message)))
            }
        }.resume()
    }
    
    static func sendAsyncRequest<T: Decodable>(
        with apiRequest: APIRequest,
        decodingType: T.Type,
        showLoadingToast: Bool = false,
        showSuccessToast: Bool = false,
        showErrorToast: Bool = false,
        customErrorToast: ((APIError) -> Toast?)? = nil
    ) async -> Result<T?, APIError> {
        await withCheckedContinuation { continuation in
            sendRequest(
                with: apiRequest,
                decodingType: decodingType,
                showLoadingToast: showLoadingToast,
                showSuccessToast: showSuccessToast,
                showErrorToast: showErrorToast,
                customErrorToast: customErrorToast,
                completion: { result in
                    continuation.resume(returning: result)
                }
            )
        }
    }
    
    static func downloadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: baseDomain + urlString) else {
            completion(nil)
            return
        }
        
        let request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 5)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // 确保没有错误，且返回的是有效图片数据
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    completion(image)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }.resume()
    }
    
    static func downloadResource<T: Decodable>(
        path: String,
        decodingType: T.Type,
        completion: @escaping (Result<T, APIError>) -> Void
    ) {
        guard let url = URL(string: baseDomain + path) else {
            completion(.failure(.unknown))
            return
        }

        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                completion(.failure(.networkError))
                return
            }
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(.decodeError))
            }
        }.resume()
    }
    
    static func downloadResourceAsync<T: Decodable>(
        path: String,
        decodingType: T.Type
    ) async -> Result<T, APIError> {
        guard let url = URL(string: baseDomain + path) else {
            return .failure(.unknown)
        }

        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return .success(decoded)
        } catch let error as DecodingError {
            return .failure(.decodeError)
        } catch {
            return .failure(.networkError)
        }
    }
    
    static func downloadFile(
        from url: URL,
        showSuccessToast: Bool = false,
        showErrorToast: Bool = false,
        completion: @escaping (Result<URL, APIError>) -> Void
    ) {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        let task = URLSession.shared.downloadTask(with: request) { tempURL, _, error in
            if error != nil {
                let toast = Toast(message: "网络错误")
                if showErrorToast {
                    DispatchQueue.main.async {
                        ToastManager.shared.show(toast: toast)
                    }
                }
                completion(.failure(.networkError))
                return
            }
            guard let tempURL = tempURL else {
                let toast = Toast(message: "资源下载失败")
                if showErrorToast {
                    DispatchQueue.main.async {
                        ToastManager.shared.show(toast: toast)
                    }
                }
                completion(.failure(.noData))
                return
            }
            let toast = Toast(message: "下载成功")
            if showSuccessToast {
                DispatchQueue.main.async {
                    ToastManager.shared.show(toast: toast)
                }
            }
            completion(.success(tempURL))
        }
        task.resume()
    }
    
    static func downloadFileAsync(
        from url: URL,
        showSuccessToast: Bool = false,
        showErrorToast: Bool = false
    ) async -> Result<URL, APIError> {
        do {
            let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
            let (tempURL, _) = try await URLSession.shared.download(for: request)
            let toast = Toast(message: "下载成功")
            if showSuccessToast {
                DispatchQueue.main.async {
                    ToastManager.shared.show(toast: toast)
                }
            }
            return .success(tempURL)
        } catch {
            let toast = Toast(message: "资源下载失败")
            if showErrorToast {
                DispatchQueue.main.async {
                    ToastManager.shared.show(toast: toast)
                }
            }
            return .failure(.networkError)
        }
    }
}
