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
    @GestureState private var isDragging: Bool = false

    func body(content: Content) -> some View {
        content
            .allowsHitTesting(!isDragging)
            .disabled(isDragging)
            .gesture(
                enabled ?
                DragGesture()
                    .updating($isDragging) {_, state, _ in
                        state = true
                    }
                    .onEnded { value in
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

// MARK: 视图稳定生命周期监听
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

// MARK: 视图首次渲染监听
extension View {
    func onFirstAppear(_ perform: @escaping () -> Void) -> some View {
        modifier(FirstAppearModifier(perform: perform))
    }
}

struct FirstAppearModifier: ViewModifier {
    @State private var hasAppeared = false
    let perform: () -> Void

    func body(content: Content) -> some View {
        content.onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            perform()
        }
    }
}

class ObservingView: UIView {
    var onAttachToWindow: (() -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            // 视图重新上屏
            onAttachToWindow?()
        }
    }
}

struct ScrollDragObserver: UIViewRepresentable {
    @Binding var isDragging: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isDragging: $isDragging)
    }

    func makeUIView(context: Context) -> UIView {
        let view = ObservingView()
        view.onAttachToWindow = {
            DispatchQueue.main.async {
                isDragging = false   // 每次上屏都重置，避免拖动时切走视图导致状态错误
            }
        }
        DispatchQueue.main.async {
            if let scrollView = findScrollView(from: view) {
                scrollView.delegate = context.coordinator
            }
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private func findScrollView(from view: UIView) -> UIScrollView? {
        var responder: UIResponder? = view
        while let next = responder?.next {
            if let scrollView = next as? UIScrollView {
                return scrollView
            }
            responder = next
        }
        return nil
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        @Binding var isDragging: Bool

        init(isDragging: Binding<Bool>) {
            self._isDragging = isDragging
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            DispatchQueue.main.async {
                self.isDragging = true
            }
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                DispatchQueue.main.async {
                    self.isDragging = false
                }
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            DispatchQueue.main.async {
                self.isDragging = false
            }
        }
    }
}

// MARK: 监听 ScrollView 拖动状态变化
extension View {
    func onScrollDragChanged(_ isDragging: Binding<Bool>) -> some View {
        self.background(
            ScrollDragObserver(isDragging: isDragging)
                .frame(width: 0, height: 0)
        )
    }
}

// MARK: UIColor
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
    
    /*private static let precomputedSoftDarkColors: [UIColor] = {
        (0..<128).compactMap { i in
            let h = CGFloat(i) / 128.0
            let s: CGFloat = 0.45
            let l: CGFloat = 0.45
            let color = UIColor(hue: h, saturation: s, brightness: l, alpha: 1)
            return color.contrastRatio(with: .white) >= 4.0 ? color : nil
        }
    }()*/
    
    private static let precomputedSoftDarkColors: [UIColor] = {
        var colors: [UIColor] = []
        let steps = 10  // 每个通道取样次数
        let minBrightness: CGFloat = 0.15
        let maxBrightness: CGFloat = 0.6

        for rStep in 0..<steps {
            for gStep in 0..<steps {
                for bStep in 0..<steps {
                    let r = 0.8 * CGFloat(rStep) / CGFloat(steps - 1)
                    let g = 0.8 * CGFloat(gStep) / CGFloat(steps - 1)
                    let b = 0.8 * CGFloat(bStep) / CGFloat(steps - 1)

                    // 计算亮度（感知亮度公式）
                    let brightness = 0.2126 * r + 0.7152 * g + 0.0722 * b

                    // 仅保留暗色调
                    guard brightness >= minBrightness, brightness <= maxBrightness else { continue }

                    // 添加柔和淡化效果：混合一点灰/白
                    let softenRatio: CGFloat = 0.2
                    let softenedR = r + (1 - r) * softenRatio
                    let softenedG = g + (1 - g) * softenRatio
                    let softenedB = b + (1 - b) * softenRatio

                    let color = UIColor(red: softenedR, green: softenedG, blue: softenedB, alpha: 1.0)

                    // 保证对比度足够（适合深色背景）
                    if color.contrastRatio(with: .white) >= 4.0 {
                        colors.append(color)
                    }
                }
            }
        }
        return colors
    }()

    static func softDarkPalette() -> [UIColor] {
        return precomputedSoftDarkColors
    }
    
    func bestSoftDarkReadableColor() -> Color {
        let (r, g, b) = self.rgbComponents
        // 过于白的背景直接黑灰色兜底
        if (r + g + b) >= 2.4 {
            return Color(red: 0.3, green: 0.3, blue: 0.3)
        }
        
        let white = UIColor.white
        var color = self
        for _ in 0..<3 {
            if color.contrastRatio(with: white) >= 4.0 {
                return Color(uiColor: color)
            }
            let (red, green, blue) = color.rgbComponents
            color = UIColor(red: red * 0.8, green: green * 0.8, blue: blue * 0.8, alpha: 1)
        }
        
        let palette = UIColor.softDarkPalette()
        let fallback = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)

        let best = palette.min(by: {
            $0.distance(to: self) < $1.distance(to: self)
        }) ?? fallback
        //print(best)
        return Color(best)
    }
}

// MARK: Color
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

// MARK: Data
extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            self.append(data)
        }
    }
}

// MARK: 自定义sheet（尽量放在enableBackGesture后使用，防止系统button与返回手势的冲突bug）
enum BottomSheetSize {
    case short      // 屏幕高度的 30%
    case medium     // 屏幕高度的 50%
    case large      // 屏幕高度的 85%
}

final class KeyboardObserver: ObservableObject {
    @Published var keyboardHeight: CGFloat = 0

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChange(notification:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }

    @objc private func keyboardWillChange(notification: Notification) {
        guard let info = notification.userInfo,
              let endFrame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }

        let height = endFrame.origin.y >= UIScreen.main.bounds.height ? 0 : endFrame.height

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: duration)) {
                self.keyboardHeight = height
            }
        }
    }
}

struct BottomSheetView<Content: View>: View {
    @Binding var isPresented: Bool
    let size: BottomSheetSize?
    let customizeHeight: CGFloat?
    let content: Content

    @State private var offsetY: CGFloat = 0

    init(isPresented: Binding<Bool>, size: BottomSheetSize?, customizeHeight: CGFloat?, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.size = size
        self.customizeHeight = customizeHeight
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            let totalHeight = geometry.size.height
            let sheetHeight = calculatedHeight(total: totalHeight)
            
            ZStack(alignment: .bottom) {
                // 背景遮罩
                Color.black.opacity(isPresented ? 0.4 : 0)
                    .ignoresSafeArea()
                    .exclusiveTouchTapGesture {
                        isPresented = false
                    }
                
                // 内容区域
                content
                    .frame(maxWidth: .infinity)
                    .frame(height: sheetHeight)
                    .clipShape(.rect(topLeadingRadius: 10, topTrailingRadius: 10, style: .continuous))
                    .offset(y: isPresented ? 0 : sheetHeight)
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .animation(.easeInOut(duration: 0.3), value: isPresented)
        }
    }

    private func calculatedHeight(total: CGFloat) -> CGFloat {
        if let height = customizeHeight {
            if height <= 0 || height > 1 {
                return total
            } else {
                return total * height
            }
        }
        if let size = size {
            switch size {
            case .short:
                return total * 0.3
            case .medium:
                return total * 0.5
            case .large:
                return total * 0.85
            }
        }
        return total
    }
}

extension View {
    func bottomSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        size: BottomSheetSize? = nil,
        customizeHeight: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        self.modifier(BottomSheetModifier(isPresented: isPresented, size: size, customizeHeight: customizeHeight, content: content))
    }
}

struct BottomSheetModifier<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let size: BottomSheetSize?
    let customizeHeight: CGFloat?
    let content: () -> SheetContent

    func body(content base: Content) -> some View {
        ZStack {
            base
            BottomSheetView(isPresented: $isPresented, size: size, customizeHeight: customizeHeight, content: self.content)
        }
    }
}

// MARK: 自定义互斥点击修饰符
extension View {
    func exclusiveTouchTapGesture(perform action: @escaping () -> Void) -> some View {
        modifier(ExclusiveTouchTapModifier(action: action))
    }
}

struct ExclusiveTouchTapModifier: ViewModifier {
    @ObservedObject var config = GlobalConfig.shared
    let action: () -> Void

    func body(content: Content) -> some View {
        content.onTapGesture {
            guard !config.isButtonLocked else { return }
            config.isButtonLocked = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                config.isButtonLocked = false
            }
        }
    }
}

extension String {
    // 将字符串中的{{xx}}替换为json中的值
    func rendered(with effectDef: JSONValue) -> String {
        // 支持 {{key}} 或 {{ key.path }}，允许 key 两侧的空白
        let pattern = #"\{\{\s*([\w\.]+)\s*\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return self }
        
        // 用 NSString 计算长度和做替换，避免 Unicode/NSRange 对不齐
        let nsSelf = self as NSString
        let fullRange = NSRange(location: 0, length: nsSelf.length)
        let matches = regex.matches(in: self, range: fullRange)
        
        // 从后往前替换，避免 range 位移
        var result = self
        for match in matches.reversed() {
            guard match.numberOfRanges == 2 else { continue }
            let full = match.range(at: 0)
            let key = match.range(at: 1)
            
            let nsResult = result as NSString
            let keyPath = nsResult.substring(with: key)              // 如 "bonus_time" 或 "skill1.bonus_time"
            let keys = keyPath.split(separator: ".").map(String.init)
            
            if let value = effectDef.value(for: keys) {
                let replacement: String
                switch value {
                case .string(let s):
                    replacement = s
                case .number(let n):
                    // 整数不带小数，小数保留两位
                    replacement = n == floor(n) ? String(Int(n)) : String(format: "%.2f", n)
                case .bool(let b):
                    replacement = b ? "true" : "false"
                default:
                    replacement = ""
                }
                // 用 NSString 的替换，避免 Range 转换问题
                result = (result as NSString).replacingCharacters(in: full, with: replacement)
            } else {
                result = (result as NSString).replacingCharacters(in: full, with: "")
            }
        }
        return result
    }
    
    // 提取描述中的 {{xx}} 或 {{xx.yy.zz}} 占位符，返回路径数组
    func extractKeys() -> [[String]] {
        let pattern = #"\{\{\s*([\w\.]+)\s*\}\}"#//#"\{\{([a-zA-Z0-9_.]+)\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        
        let nsrange = NSRange(startIndex..<endIndex, in: self)
        let matches = regex.matches(in: self, options: [], range: nsrange)
        
        return matches.compactMap { match in
            if let range = Range(match.range(at: 1), in: self) {
                let path = String(self[range])
                return path.split(separator: ".").map { String($0) }
            }
            return nil
        }
    }
}

extension View {
    @ViewBuilder
    func onValueChange<V: Equatable>(of value: V, perform action: @escaping () -> Void) -> some View {
        if #available(iOS 17.0, *) {
            // iOS17+ 支持零参数闭包
            self.onChange(of: value, action)
        } else {
            // iOS16 必须写带参数的闭包
            self.onChange(of: value) { _ in action() }
        }
    }
}

// MARK: 系统原生侧滑返回手势
struct SwipeBackGestureController: UIViewControllerRepresentable {
    let isEnabled: Bool
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled = false
        controller.view.isOpaque = false
        controller.view.isHidden = true
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            if let nav = uiViewController.navigationController {
                nav.interactivePopGestureRecognizer?.isEnabled = isEnabled
                // 仅当启用时移除 delegate，否则还原默认 delegate
                nav.interactivePopGestureRecognizer?.delegate = isEnabled ? nil : context.coordinator
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {}
}

extension View {
    func enableSwipeBackGesture(_ enabled: Bool = true) -> some View {
        self.background(
            SwipeBackGestureController(isEnabled: enabled)
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)
        )
    }
}
