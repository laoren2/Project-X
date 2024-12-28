//
//  LoginView.swift
//  sportsx
//
//  Created by 任杰 on 2024/8/8.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject private var userManager = UserManager.shared
    @State private var phoneNumber: String = ""
    @State private var password: String = ""
    @State private var verificationCode: String = ""
    @State private var isPasswordLogin: Bool = true // 默认为密码登录模式
    @Binding var showingLogin: Bool

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    showingLogin = false
                }) {
                    Image(systemName: "xmark")
                        .padding()
                }
                Spacer()
            }
            .padding(.top, 10)
            
            // 登录方式切换
            Picker("登录方式", selection: $isPasswordLogin) {
                Text("密码登录").tag(true)
                Text("验证码登录").tag(false)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            TextField("请输入手机号", text: $phoneNumber)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
            
            if isPasswordLogin {
                SecureField("请输入密码", text: $password)
                    .padding()
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            } else {
                Button("发送验证码") {
                    // 这里应调用发送验证码的逻辑
                    print("验证码已发送")
                }
                .padding()
                
                TextField("请输入验证码", text: $verificationCode)
                    .padding()
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            Button("登录") {
                loginUser()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.top, 10)
        }
        .padding()
    }
    
    func loginUser() {
        guard !phoneNumber.isEmpty else { return }
        if isPasswordLogin {
            if password == "correctPassword" {
                userManager.loginUser(phoneNumber: phoneNumber)
                showingLogin = false
            }
        } else {
            if verificationCode == "1234" {
                userManager.loginUser(phoneNumber: phoneNumber)
                showingLogin = false
            }
        }
    }
}

//#Preview {
    //LoginView()
//}
