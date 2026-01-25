//
//  PopupWindowSystem.swift
//  sportsx
//
//  Created by 任杰 on 2025/12/11.
//

import SwiftUI
import Foundation


enum PopupButtonStyle {
    case cancel
    case confirm
}

struct PopupButton {
    let title: String?
    let style: PopupButtonStyle?
    var buttonView: AnyView?
    let action: (() -> Void)?
    
    init(title: String? = nil, style: PopupButtonStyle? = nil, buttonView: AnyView? = nil, action: (() -> Void)?) {
        self.title = title
        self.style = style
        self.buttonView = buttonView
        self.action = action
    }

    init<Content: View>(
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = nil
        self.style = nil
        self.buttonView = AnyView(content())
        self.action = action
    }
    
    static func confirm(_ title: String = "action.confirm", _ action: (() -> Void)? = nil) -> PopupButton {
        PopupButton(title: title, style: .confirm, action: action)
    }

    static func cancel(_ title: String = "action.cancel", _ action: (() -> Void)? = nil) -> PopupButton {
        PopupButton(title: title, style: .cancel, action: action)
    }
}

struct PopupInfo: Identifiable {
    let id = UUID()
    var title: String?
    var message: String?
    var messageView: AnyView?
    var doNotShowAgainKey: String?
    var doNotShowAgain: Bool = false
    var bottomButtons: [PopupButton]
}

class PopupWindowManager: ObservableObject {
    static let shared = PopupWindowManager()
    
    private init() {}
    
    @Published var popups: [PopupInfo] = []
    
    func presentPopup(
        title: String? = nil,
        message: String? = nil,
        messageView: AnyView? = nil,
        doNotShowAgainKey: String? = nil,
        bottomButtons: [PopupButton]
    ) {
        if let key = doNotShowAgainKey {
            guard !checkDoNotShowAgain(forKey: key) else { return }
        }
        self.popups.append(
            PopupInfo(
                title: title,
                message: message,
                messageView: messageView,
                doNotShowAgainKey: doNotShowAgainKey,
                bottomButtons: bottomButtons
            )
        )
    }
    
    func presentPopup<Content: View>(
        title: String? = nil,
        doNotShowAgainKey: String? = nil,
        bottomButtons: [PopupButton],
        @ViewBuilder msgContent: () -> Content
    ) {
        presentPopup(
            title: title,
            messageView: AnyView(msgContent()),
            doNotShowAgainKey: doNotShowAgainKey,
            bottomButtons: bottomButtons
        )
    }
    
    func dismissPopup() -> PopupInfo? {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        return popups.popLast()
    }
    
    func checkDoNotShowAgain(forKey key: String) -> Bool {
        return UserDefaults.standard.bool(forKey: "popup.doNotShowAgain.\(key)")
    }
}

struct PopupContainerView: View {
    @ObservedObject var popupManager = PopupWindowManager.shared
    
    var body: some View {
        ZStack {
            if !popupManager.popups.isEmpty {
                Color.black.opacity(0.1)    // 用 clear 在iOS16上会穿透
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .exclusiveTouchTapGesture {
                        if let popup = popupManager.dismissPopup(), let key = popup.doNotShowAgainKey {
                            UserDefaults.standard.set(popup.doNotShowAgain, forKey: "popup.doNotShowAgain.\(key)")
                        }
                    }
            }
            ForEach(Array(popupManager.popups.enumerated()), id: \.element.id) { index, popup in
                VStack(spacing: 16) {
                    if let title = popup.title {
                        Text(LocalizedStringKey(title))
                            .font(.title3.bold())
                            .foregroundColor(.white)
                    }
                    
                    if let customView = popup.messageView {
                        customView
                    } else if let msg = popup.message {
                        Text(LocalizedStringKey(msg))
                            .font(.subheadline)
                            .foregroundStyle(Color.secondText)
                            .multilineTextAlignment(.center)
                    }
                    
                    // "不再显示"模块，用于控制某些场景下一次是否继续弹出
                    if popup.doNotShowAgainKey != nil {
                        HStack(spacing: 4) {
                            Image(systemName: popup.doNotShowAgain ? "checkmark.circle" : "circle")
                                .font(.footnote)
                                .foregroundStyle(popup.doNotShowAgain ? Color.orange : Color.secondText)
                                .onTapGesture {
                                    if let idx = popupManager.popups.firstIndex(where: { $0.id == popup.id }) {
                                        popupManager.popups[idx].doNotShowAgain.toggle()
                                    }
                                }
                            Text("popup.no_reminder")
                                .foregroundColor(Color.secondText)
                                .font(.footnote)
                        }
                    }
                    
                    if !popup.bottomButtons.isEmpty {
                        HStack(spacing: 30) {
                            ForEach(Array(popup.bottomButtons.enumerated()), id: \.offset) { (_, btn) in
                                Button {
                                    if index == popupManager.popups.count - 1 {
                                        if let key = popup.doNotShowAgainKey {
                                            UserDefaults.standard.set(popup.doNotShowAgain, forKey: "popup.doNotShowAgain.\(key)")
                                        }
                                        popupManager.dismissPopup()
                                        btn.action?()
                                    }
                                } label: {
                                    if let customBtnView = btn.buttonView {
                                        customBtnView
                                    } else if let title = btn.title {
                                        Text(LocalizedStringKey(title))
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 20)
                                            .background(
                                                btn.style == .confirm ? Color.green : Color.gray.opacity(0.3)
                                            )
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                    }
                                }
                            }
                        }
                        .padding(.top, 10)
                    }
                }
                .padding(20)
                .frame(width: 300)
                .background(Color.defaultBackground)
                .cornerRadius(18)
                .transition(.asymmetric(
                    insertion: .scale.animation(.spring(response: 0.3, dampingFraction: 0.5)),
                    removal: .scale(scale: 0.9).combined(with: .opacity).animation(.easeInOut(duration: 0.2))
                ))
                .zIndex(Double(index) + 1000)
            }
        }
    }
}
