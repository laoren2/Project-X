//
//  ViewModifier.swift
//  sportsx
//
//  Created by 任杰 on 2025/4/24.
//

import SwiftUI
import MapKit


// MARK: 导航中右划返回手势
extension View {
    func enableBackGesture(_ enabled: Bool = true, onBack: (() -> Void)? = nil) -> some View {
        modifier(BackGestureModifier(enabled: enabled, onBack: onBack))
    }
}

private struct BackGestureModifier: ViewModifier {
    @EnvironmentObject var appState: AppState
    let enabled: Bool
    let onBack: (() -> Void)?
    @State private var isDragging: Bool = false

    func body(content: Content) -> some View {
        content
            .allowsHitTesting(!isDragging)
            .gesture(
                enabled ?
                DragGesture()
                    .onChanged { _ in
                        isDragging = true
                    }
                    .onEnded { value in
                        isDragging = false
                        let translation = value.translation.width
                        let distanceThreshold: CGFloat = 150  // 距离阈值，超过这个距离就触发动作
                        
                        // 速度阈值，单位是点/秒
                        let velocityThreshold: CGFloat = 200
                        let minThreshold: CGFloat = 20  // 最小距离阈值，即使速度很快也需要至少这么多距离
                        
                        // 根据距离或速度来判断是否返回
                        if translation > distanceThreshold || (translation > minThreshold && value.velocity.width > velocityThreshold) {
                            if let onBack = onBack {
                                onBack()
                            } else {
                                appState.navigationManager.removeLast()
                            }
                        }
                    }
                : nil
            )
    }
}

// MARK: 点击收起键盘
extension View {
    func hideKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }
    }
}

// MARK: 拖动收起键盘
extension View {
    func hideKeyboardOnScroll() -> some View {
        self.simultaneousGesture(
            DragGesture().onChanged { _ in
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        )
    }
}

// MARK: 稳定生命周期监听

extension View {
    func onStableAppear(perform: @escaping () -> Void) -> some View {
        background(
            StableLifecycleObserver(
                onAppear: perform,
                onDisappear: {}
            )
            .frame(width: 0, height: 0)
        )
    }

    func onStableDisappear(perform: @escaping () -> Void) -> some View {
        background(
            StableLifecycleObserver(
                onAppear: {},
                onDisappear: perform
            )
            .frame(width: 0, height: 0)
        )
    }
}

struct StableLifecycleObserver: UIViewControllerRepresentable {
    var onAppear: () -> Void
    var onDisappear: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = LifecycleViewController()
        controller.onAppear = onAppear
        controller.onDisappear = onDisappear
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    class LifecycleViewController: UIViewController {
        var onAppear: (() -> Void)?
        var onDisappear: (() -> Void)?

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            onAppear?()
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            onDisappear?()
        }
    }
}

extension UIColor {
    var rgbComponents: (CGFloat, CGFloat, CGFloat) {
        var (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 1)
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }

    private func contrastRatio(with other: UIColor) -> CGFloat {
        func luminance(r: CGFloat, g: CGFloat, b: CGFloat) -> CGFloat {
            func adjust(_ c: CGFloat) -> CGFloat {
                c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * adjust(r) + 0.7152 * adjust(g) + 0.0722 * adjust(b)
        }
        let (r1, g1, b1) = self.rgbComponents
        let (r2, g2, b2) = other.rgbComponents
        let l1 = luminance(r: r1, g: g1, b: b1) + 0.05
        let l2 = luminance(r: r2, g: g2, b: b2) + 0.05
        return max(l1, l2) / min(l1, l2)
    }

    private func distance(to other: UIColor) -> CGFloat {
        let (r1, g1, b1) = self.rgbComponents
        let (r2, g2, b2) = other.rgbComponents
        return sqrt(pow(r1 - r2, 2) + pow(g1 - g2, 2) + pow(b1 - b2, 2))
    }
    
    private static let precomputedSoftDarkColors: [UIColor] = {
        (0..<96).compactMap { i in
            let h = CGFloat(i) / 96.0
            let s: CGFloat = 0.4
            let l: CGFloat = 0.4
            let color = UIColor(hue: h, saturation: s, brightness: l, alpha: 1)
            return color.contrastRatio(with: .white) >= 4.5 ? color : nil
        }
    }()

    static func softDarkPalette() -> [UIColor] {
        return precomputedSoftDarkColors
    }
    
    func bestSoftDarkReadableColor() -> Color {
        let (r, g, b) = self.rgbComponents
        
        let white = UIColor.white
        if contrastRatio(with: white) >= 4.5 {
            return Color(red: r, green: g, blue: b)
        }
        
        let palette = UIColor.softDarkPalette()
        let fallback = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)

        let best = palette.min(by: {
            $0.distance(to: self) < $1.distance(to: self)
        }) ?? fallback

        return Color(best)
    }
}

extension Color {
    static let defaultBackground = Color(red: 0.1, green: 0.1, blue: 0.1)
    
    static let secondText: Color = .white.opacity(0.8)
    
    static let thirdText: Color = .white.opacity(0.5)
    
    func softenColor(blendWithWhiteRatio ratio: CGFloat) -> Color {
        // Clamp ratio to 0...1
        let clamped = max(0, min(1, ratio))
        
        // Convert to UIColor for component access
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        // Blend with white (1.0, 1.0, 1.0)
        let blendedR = r + (1.0 - r) * clamped
        let blendedG = g + (1.0 - g) * clamped
        let blendedB = b + (1.0 - b) * clamped

        return Color(red: blendedR, green: blendedG, blue: blendedB)
    }
}

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            self.append(data)
        }
    }
}

