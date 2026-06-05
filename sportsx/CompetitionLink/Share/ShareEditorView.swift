//
//  ShareEditorView.swift
//  sportsx
//
//  运动结算分享图编辑器：在用户选择的背景图上叠加可拖拽/缩放的数据水印，
//  导出 9:16 图片并保存到相册。先用于 route training 结算页，后续 3 个 sport 复用。
//

import SwiftUI
import PhotosUI
import CoreLocation
import MapKit

// 分享图背景模式
enum ShareBackgroundMode {
    case photo      // 用户选择的照片
    case map        // 轨迹 + 其所在地图区域整体作为背景
}

// 单个元素的可编辑状态（位置/缩放/是否添加）
struct ShareElementState {
    var enabled: Bool
    var offset: CGSize = .zero
    var scale: CGFloat = 1
    var placed: Bool = false        // 是否已根据画布尺寸放置过默认位置
}

// 上报元素未缩放时的固有尺寸
private struct ShareElementSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

// 吸附对齐时的轻震动
enum ShareHaptics {
    static let generator = UIImpactFeedbackGenerator(style: .light)
    static func snap() { generator.impactOccurred(intensity: 0.6) }
}

// MARK: - 元素视觉内容（编辑态与导出态共用，保证 WYSIWYG）

struct ShareElementContent: View {
    let kind: ShareElementKind
    let metrics: ShareMetrics
    let trackColor: Color
    /// metricChip / logo 的文字色（根据所覆盖背景自适应黑/白）
    var textColor: Color = .white
    /// 轨迹元素基础边长（再由 element.scale 缩放）
    var trackBaseSize: CGFloat = 160

    var body: some View {
        switch kind {
        case .track:
            ShareTrackShape(coordinates: metrics.coordinates)
                .stroke(trackColor, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                .frame(width: trackBaseSize, height: trackBaseSize)
                .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
        case .duration:
            metricChip(value: metrics.durationText, unitKey: nil, labelKey: "share.element.duration")
        case .pace:
            metricChip(value: metrics.paceOrSpeedText, unitKey: metrics.paceOrSpeedUnitKey, labelKey: "share.element.pace")
        case .heartRate:
            metricChip(value: metrics.heartRateText, unitKey: "heartrate.unit", labelKey: "share.element.heart_rate")
        case .elevationGain:
            metricChip(value: metrics.elevationGainText, unitKey: "distance.m", labelKey: "share.element.elevation_gain")
        case .logo:
            HStack(spacing: 6) {
                Image("single_app_icon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 25)
                Image("app_logo_text")
                    .renderingMode(.template)      // 作为模板，用 textColor 着色（支持动态黑/白）
                    .resizable()
                    .scaledToFit()
                    .frame(height: 25)
            }
            .fixedSize()
            .foregroundStyle(textColor)
            .shadow(color: shadowColor, radius: 3, x: 0, y: 1)
        }
    }

    // 文字为白时用深阴影、为黑时用浅阴影，弱化边缘
    private var shadowColor: Color {
        textColor == .white ? .black.opacity(0.4) : .white.opacity(0.4)
    }

    private func metricChip(value: String, unitKey: String?, labelKey: String) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                if let unitKey, !unitKey.isEmpty {
                    Text(LocalizedStringKey(unitKey))
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            Text(LocalizedStringKey(labelKey))
                .font(.system(size: 12, weight: .medium))
                .opacity(0.85)
        }
        // 固定为固有尺寸，避免拖到边缘被画布压窄导致测量尺寸变小、限制失效
        .fixedSize()
        .foregroundStyle(textColor)
        .shadow(color: shadowColor, radius: 3, x: 0, y: 1)
    }
}

// MARK: - 可拖拽/缩放的元素包装（仅编辑态使用）

struct InteractiveShareElement<Content: View>: View {
    @Binding var state: ShareElementState
    let canvasSize: CGSize
    let snapEnabled: Bool
    let snapThreshold: CGFloat
    let snapTargetsX: [CGFloat]      // 其他元素中心 + 画布中心(0)
    let snapTargetsY: [CGFloat]
    let isSelected: Bool
    let onSelect: () -> Void
    let onSizeChange: (CGSize) -> Void
    // 上报对齐辅助线位置（吸附时为目标中心相对画布中心的偏移，否则 nil）
    let onGuides: (_ x: CGFloat?, _ y: CGFloat?) -> Void
    // 拖动/缩放结束后回调（用于重算自适应文字色）
    var onCommit: () -> Void = {}
    // 拖动过程中的实时回调（限频在父级做，用于实时文字色）
    var onLiveMove: () -> Void = {}
    let content: Content

    // 本元素未缩放固有尺寸（自身测量，限制范围时直接用，避免依赖父级字典/闭包导致的过期值）
    @State private var contentSize: CGSize = .zero
    @State private var dragStart: CGSize? = nil
    @State private var wasSnappedX = false
    @State private var wasSnappedY = false

    var body: some View {
        content
            .background(
                GeometryReader { g in
                    Color.clear
                        .onAppear { updateSize(g.size) }
                        .onChange(of: g.size) { updateSize($0) }
                }
            )
            // 轨迹是细线描边，默认只有线上可点；用矩形 contentShape 让整个元素框都可点选/拖拽
            .contentShape(Rectangle())
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(isSelected ? 0.9 : 0), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .padding(-6)
            )
            .scaleEffect(state.scale)
            .offset(state.offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if dragStart == nil {
                            dragStart = state.offset
                            onSelect()
                        }
                        let base = dragStart ?? state.offset
                        var x = base.width + value.translation.width
                        var y = base.height + value.translation.height
                        var snapX = false, snapY = false
                        if snapEnabled {
                            if let t = snapTargetsX.min(by: { abs($0 - x) < abs($1 - x) }), abs(t - x) <= snapThreshold { x = t; snapX = true }
                            if let t = snapTargetsY.min(by: { abs($0 - y) < abs($1 - y) }), abs(t - y) <= snapThreshold { y = t; snapY = true }
                        }
                        let clamped = clamp(CGSize(width: x, height: y))
                        state.offset = clamped
                        // 被边界裁掉则不算吸附
                        let finalSnapX = snapX && abs(clamped.width - x) < 0.5
                        let finalSnapY = snapY && abs(clamped.height - y) < 0.5
                        if finalSnapX && !wasSnappedX { ShareHaptics.snap() }
                        if finalSnapY && !wasSnappedY { ShareHaptics.snap() }
                        wasSnappedX = finalSnapX
                        wasSnappedY = finalSnapY
                        onGuides(finalSnapX ? clamped.width : nil, finalSnapY ? clamped.height : nil)
                        onLiveMove()
                    }
                    .onEnded { _ in
                        dragStart = nil
                        wasSnappedX = false
                        wasSnappedY = false
                        onGuides(nil, nil)
                        onCommit()
                    }
            )
            .onTapGesture { onSelect() }
    }

    // 把偏移限制在画布内（用本元素自测尺寸）
    private func clamp(_ offset: CGSize) -> CGSize {
        guard canvasSize.width > 0, contentSize.width > 0 else { return offset }
        let halfW = contentSize.width * state.scale / 2
        let halfH = contentSize.height * state.scale / 2
        let maxX = max(canvasSize.width / 2 - halfW, 0)
        let maxY = max(canvasSize.height / 2 - halfH, 0)
        return CGSize(width: min(max(offset.width, -maxX), maxX),
                      height: min(max(offset.height, -maxY), maxY))
    }

    private func updateSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0, contentSize != size else { return }
        contentSize = size
        onSizeChange(size)
        // 测得尺寸后把当前偏移夹回边界（修正默认位置可能的越界）
        let c = clamp(state.offset)
        if c != state.offset { state.offset = c }
    }
}

// MARK: - 导出用的纯净画布（无选中框/手势）

struct ShareExportCanvas: View {
    let metrics: ShareMetrics
    let states: [ShareElementKind: ShareElementState]
    let trackColor: Color
    let textColors: [ShareElementKind: Color]
    let bgImage: UIImage?
    let size: CGSize

    var body: some View {
        ZStack {
            ShareBackground(bgImage: bgImage)
            ForEach(ShareElementKind.allCases) { kind in
                if let st = states[kind], st.enabled {
                    ShareElementContent(kind: kind, metrics: metrics, trackColor: trackColor, textColor: textColors[kind] ?? .white)
                        .scaleEffect(st.scale)
                        .offset(st.offset)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

struct ShareBackground: View {
    let bgImage: UIImage?
    var body: some View {
        Group {
            if let bgImage {
                Image(uiImage: bgImage)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color(red: 0.15, green: 0.16, blue: 0.22), Color(red: 0.07, green: 0.08, blue: 0.12)],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
    }
}

// MARK: - 编辑器主体

struct ShareEditorView: View {
    let metrics: ShareMetrics
    @Environment(\.dismiss) private var dismiss

    @State private var states: [ShareElementKind: ShareElementState] = [:]
    @State private var trackColor: Color = .white
    @State private var photoImage: UIImage?                 // 照片背景
    @State private var mapImage: UIImage?                   // 轨迹地图背景（合成结果）
    @State private var mapSnapshot: MKMapSnapshotter.Snapshot?   // 缓存地图快照，换轨迹色时重绘
    @State private var backgroundMode: ShareBackgroundMode = .photo
    @State private var isGeneratingMap = false
    @State private var mapDarkMode = false                  // 地图浅色/深色风格
    @State private var selectedItem: PhotosPickerItem?
    @State private var showPicker = false
    @State private var selected: ShareElementKind?
    @State private var isSaving = false
    @State private var canvasSizeState: CGSize = .zero      // 当前编辑画布尺寸（导出沿用，保证 offset 一致）
    @State private var elementSizes: [ShareElementKind: CGSize] = [:]   // 各元素未缩放固有尺寸
    @State private var snapEnabled: Bool = true            // 是否启用自动吸附
    @State private var guideX: CGFloat? = nil              // 竖向对齐辅助线位置（相对画布中心）
    @State private var guideY: CGFloat? = nil              // 横向对齐辅助线位置
    @State private var textColors: [ShareElementKind: Color] = [:]   // 各文字元素自适应黑/白色
    @State private var lastLiveSampleTime: TimeInterval = 0           // 拖动实时取色限频时间戳
#if DEBUG
    @State private var debugSampleText: String = ""                  // DEBUG: 采样对比度信息
    @State private var debugSampleColor: Color = .clear              // DEBUG: 采样到的平均色
#endif

    private let aspect: CGFloat = 9.0 / 16.0      // 宽 : 高
    private let exportWidth: CGFloat = 1080
    private let minScale: CGFloat = 0.5
    private let snapThreshold: CGFloat = 8
    private let liveSampleInterval: TimeInterval = 0.04    // 拖动实时取色最小间隔（~25fps）

    // 当前生效的背景图（照片 / 轨迹地图）
    private var backgroundImage: UIImage? {
        backgroundMode == .map ? mapImage : photoImage
    }
    private var canUseMap: Bool { metrics.coordinates.count > 1 }

    init(metrics: ShareMetrics) {
        self.metrics = metrics
        // 默认进入地图模式；轨迹点不足时退回照片模式
        _backgroundMode = State(initialValue: metrics.coordinates.count > 1 ? .map : .photo)
    }

    var body: some View {
        GeometryReader { geo in
            let canvasSize = canvasSize(in: geo.size)
            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                canvas(size: canvasSize)
                    .onAppear { applyCanvasSize(canvasSize) }
                    .onChange(of: canvasSize) { applyCanvasSize($0) }
                Spacer(minLength: 0)
                controlPanel
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
        }
        .photosPicker(isPresented: $showPicker, selection: $selectedItem, matching: .images)
        .onValueChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    let normalized = ImageTool.normalizedUp(img)   // 烘焙 .up 朝向，保证采样坐标与像素一致
                    await MainActor.run {
                        photoImage = normalized
                        updateAllTextColors()
                    }
                }
            }
        }
        // 地图模式下改轨迹颜色时，在缓存快照上重绘轨迹（不重新请求地图）
        .onValueChange(of: trackColor) { _, _ in
            if backgroundMode == .map, let snap = mapSnapshot {
                compositeTrack(on: snap)
            }
        }
        .onFirstAppear {
            // 默认地图模式：首次进入即生成地图背景
            if backgroundMode == .map, mapImage == nil {
                generateMapBackground()
            }
        }
    }

    // MARK: 顶部栏
    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Spacer()
            Text("share.editor.title")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Button(action: { save() }) {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text("share.action.save")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.orange)
                }
            }
            .disabled(isSaving)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: 画布（编辑态）
    private func canvas(size: CGSize) -> some View {
        ZStack {
            ShareBackground(bgImage: backgroundImage)
                .frame(width: size.width, height: size.height)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture { selected = nil }

            ForEach(ShareElementKind.allCases) { kind in
                if states[kind]?.enabled == true {
                    InteractiveShareElement(
                        state: bindingFor(kind),
                        canvasSize: size,
                        snapEnabled: snapEnabled,
                        snapThreshold: snapThreshold,
                        snapTargetsX: snapTargets(for: kind, axisX: true),
                        snapTargetsY: snapTargets(for: kind, axisX: false),
                        isSelected: selected == kind,
                        onSelect: { selected = kind },
                        onSizeChange: { setElementSize(kind, $0) },
                        onGuides: { x, y in guideX = x; guideY = y },
                        onCommit: { updateTextColor(for: kind) },
                        onLiveMove: { liveUpdateTextColor(for: kind) },
                        content: ShareElementContent(kind: kind, metrics: metrics, trackColor: trackColor, textColor: textColors[kind] ?? .white)
                    )
                }
            }

            // 对齐辅助线（吸附时显示）
            if let gx = guideX {
                Rectangle()
                    .fill(Color.orange)
                    .frame(width: 1, height: size.height)
                    .offset(x: gx)
                    .allowsHitTesting(false)
            }
            if let gy = guideY {
                Rectangle()
                    .fill(Color.orange)
                    .frame(width: size.width, height: 1)
                    .offset(y: gy)
                    .allowsHitTesting(false)
            }

            if isGeneratingMap {
                ZStack {
                    Color.black.opacity(0.35)
                    ProgressView().tint(.white)
                }
                .allowsHitTesting(false)
            }

            #if DEBUG
            // DEBUG: 红框标出当前选中文字元素「实际被采样」的背景区域
            if let sel = selected, sel != .track, let sz = elementSizes[sel], let st = states[sel] {
                Rectangle()
                    .stroke(Color.red, lineWidth: 1)
                    .frame(width: sz.width * st.scale, height: sz.height * st.scale)
                    .offset(st.offset)
                    .allowsHitTesting(false)
            }
            #endif
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        #if DEBUG
        .overlay(alignment: .top) {
            if let sel = selected, sel != .track {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(debugSampleColor)
                        .frame(width: 16, height: 16)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(0.6), lineWidth: 1))
                    Text(debugSampleText)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule().fill(.black.opacity(0.65)))
                .padding(.top, 6)
            }
        }
        #endif
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            VStack(spacing: 12) {
                if selected != nil {
                    scaleSlider
                }
                snapToggleButton
                if backgroundMode == .map {
                    mapStyleButton
                }
            }
            .padding(.leading, 6)
        }
    }

    // 左侧竖向缩放拖杆，控制当前选中元素的缩放
    private var scaleSlider: some View {
        let length: CGFloat = 170
        return VStack(spacing: 8) {
            Image(systemName: "plus.magnifyingglass")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
            Slider(value: scaleBinding, in: minScale...sliderMax)
                .frame(width: length)
                .rotationEffect(.degrees(-90))
                .frame(width: 32, height: length)
                .tint(.orange)
            Image(systemName: "minus.magnifyingglass")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(Capsule().fill(Color.black.opacity(0.35)))
    }

    // 自动吸附开关（圆形按钮）
    private var snapToggleButton: some View {
        Image(systemName: snapEnabled ? "dot.scope" : "circle.dashed")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(snapEnabled ? Color.orange : Color.white.opacity(0.8))
            .frame(width: 40, height: 40)
            .background(Circle().fill(Color.black.opacity(0.35)))
            .exclusiveTouchTapGesture { snapEnabled.toggle() }
    }
    
    // 地图浅/深风格切换（仅地图模式）
    private var mapStyleButton: some View {
        Image(systemName: mapDarkMode ? "moon.stars.fill" : "sun.max.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(Circle().fill(Color.black.opacity(0.35)))
            .opacity(isGeneratingMap ? 0.5 : 1)
            .exclusiveTouchTapGesture {
                guard !isGeneratingMap else { return }
                toggleMapStyle()
            }
    }

    // MARK: 底部控制面板
    private var controlPanel: some View {
        VStack(spacing: 12) {
            // 元素开关（地图模式下隐藏「轨迹」开关，轨迹已并入背景）
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ShareElementKind.allCases) { kind in
                        if !(kind == .track && backgroundMode == .map) {
                            elementToggleChip(kind)
                        }
                    }
                }
                .padding(.horizontal)
            }

            // 轨迹颜色（地图模式始终可调；照片模式在轨迹开启时可调）
            if backgroundMode == .map || states[.track]?.enabled == true {
                HStack {
                    Image(systemName: "paintbrush.fill")
                        .foregroundStyle(Color.secondText)
                    ColorPicker("share.editor.track_color", selection: $trackColor, supportsOpacity: false)
                        .foregroundStyle(Color.white)
                }
                .padding(.horizontal)
            }
            
            // 背景模式选择
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "person.and.background.dotted")
                        .foregroundStyle(Color.secondText)
                    Text("share.editor.background")
                        .foregroundStyle(Color.white)
                }
                HStack(spacing: 10) {
                    bgModeButton(.photo, titleKey: "share.editor.bg_photo", icon: "photo")
                    bgModeButton(.map, titleKey: "share.editor.bg_map", icon: "map", disabled: !canUseMap)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal)

            // 选择背景图（仅照片模式）
            if backgroundMode == .photo {
                Button(action: { showPicker = true }) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("share.editor.choose_background")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.white.opacity(0.15)))
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 12)
        .background(Color(white: 0.08).ignoresSafeArea(edges: .bottom))
    }

    private func bgModeButton(_ mode: ShareBackgroundMode, titleKey: String, icon: String, disabled: Bool = false) -> some View {
        let isActive = backgroundMode == mode
        return HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 12))
            Text(LocalizedStringKey(titleKey)).font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(isActive ? Color.white : Color.thirdText)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Capsule().fill(isActive ? Color.orange : Color.secondBackground))
        .opacity(disabled ? 0.4 : 1)
        .exclusiveTouchTapGesture {
            guard !disabled else { return }
            switchBackgroundMode(mode)
        }
    }

    private func elementToggleChip(_ kind: ShareElementKind) -> some View {
        let enabled = states[kind]?.enabled == true
        let isLogo = kind == .logo
        // 心率无数据时禁用
        let disabled = (kind == .heartRate && !metrics.hasHeartRate) || isLogo
        return HStack(spacing: 5) {
            Image(systemName: kind.iconName)
                .font(.system(size: 12))
            Text(LocalizedStringKey(kind.titleKey))
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(enabled ? Color.white : Color.thirdText)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule().fill(enabled ? Color.orange : Color.secondBackground)
        )
        .opacity(disabled && !enabled ? 0.4 : 1)
        .exclusiveTouchTapGesture {
            guard !disabled else { return }
            toggle(kind)
        }
    }

    // MARK: 逻辑

    private func bindingFor(_ kind: ShareElementKind) -> Binding<ShareElementState> {
        Binding(
            get: { states[kind] ?? ShareElementState(enabled: false) },
            set: { states[kind] = $0 }
        )
    }

    // 仅记录尺寸供拖杆最大缩放/重夹使用（元素拖动时的边界限制由元素自身用本地尺寸完成）
    private func setElementSize(_ kind: ShareElementKind, _ size: CGSize) {
        guard size.width > 0, size.height > 0, elementSizes[kind] != size else { return }
        elementSizes[kind] = size
        updateTextColor(for: kind)      // 尺寸确定后即可算覆盖区域的自适应文字色
    }

    // 把偏移限制在画布内（元素缩放后的外框不超出边界）
    private func clampOffset(_ offset: CGSize, size: CGSize, scale: CGFloat) -> CGSize {
        guard canvasSizeState.width > 0 else { return offset }
        let halfW = size.width * scale / 2
        let halfH = size.height * scale / 2
        let maxX = max(canvasSizeState.width / 2 - halfW, 0)
        let maxY = max(canvasSizeState.height / 2 - halfH, 0)
        return CGSize(width: min(max(offset.width, -maxX), maxX),
                      height: min(max(offset.height, -maxY), maxY))
    }

    // 元素允许的最大缩放（保证缩放后不超出画布）
    private func maxScale(for kind: ShareElementKind) -> CGFloat {
        guard let s = elementSizes[kind], s.width > 0, s.height > 0,
              canvasSizeState.width > 0, canvasSizeState.height > 0 else { return 3 }
        let fit = min(canvasSizeState.width / s.width, canvasSizeState.height / s.height)
        return max(minScale, min(fit, 4))
    }

    private var sliderMax: CGFloat {
        guard let kind = selected else { return 3 }
        return max(maxScale(for: kind), minScale + 0.01)
    }

    // 吸附目标中心：画布中心(0) + 其他已启用元素的中心
    private func snapTargets(for kind: ShareElementKind, axisX: Bool) -> [CGFloat] {
        var targets: [CGFloat] = [0]
        for (k, st) in states where k != kind && st.enabled {
            targets.append(axisX ? st.offset.width : st.offset.height)
        }
        return targets
    }

    // 缩放拖杆绑定：改缩放的同时重新限制偏移，保证不超出画布
    private var scaleBinding: Binding<CGFloat> {
        Binding(
            get: { selected.flatMap { states[$0]?.scale } ?? 1 },
            set: { newVal in
                guard let kind = selected, var st = states[kind] else { return }
                st.scale = min(max(newVal, minScale), maxScale(for: kind))
                st.offset = clampOffset(st.offset, size: elementSizes[kind] ?? .zero, scale: st.scale)
                states[kind] = st
                updateTextColor(for: kind)
            }
        )
    }

    private func canvasSize(in available: CGSize) -> CGSize {
        // 首帧或异常布局时 available 可能为 0/非有限，直接返回 .zero 避免负/非有限 frame
        guard available.width.isFinite, available.height.isFinite,
              available.width > 0, available.height > 0 else { return .zero }
        // 预留顶部栏 + 底部面板高度
        let reservedH: CGFloat = 220
        let maxH = max(available.height - reservedH, 1)
        let maxW = max(available.width - 24, 1)
        var w = maxW
        var h = w / aspect
        if h > maxH {
            h = maxH
            w = h * aspect
        }
        return CGSize(width: max(w, 1), height: max(h, 1))
    }

    // 仅在拿到有效画布尺寸时记录并放置默认位置（首帧可能为 .zero）
    private func applyCanvasSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        canvasSizeState = size
        setupDefaultsIfNeeded(canvasSize: size)
    }

    private func setupDefaultsIfNeeded(canvasSize: CGSize) {
        guard canvasSize.width > 0 else { return }
        var changed = false
        for kind in ShareElementKind.allCases {
            var st = states[kind] ?? ShareElementState(enabled: defaultEnabled(kind))
            if states[kind] == nil { changed = true }
            if !st.placed {
                let anchor = defaultAnchor(kind)
                st.offset = CGSize(width: anchor.x * canvasSize.width, height: anchor.y * canvasSize.height)
                st.placed = true
                changed = true
            }
            states[kind] = st
        }
        if changed { /* 触发刷新 */ }
    }

    private func defaultEnabled(_ kind: ShareElementKind) -> Bool {
        switch kind {
        case .duration, .pace, .logo: return true
        case .track: return backgroundMode != .map      // 地图模式下轨迹并入背景，不作为叠加元素
        case .heartRate: return false
        case .elevationGain: return false
        }
    }

    // 默认锚点（画布尺寸的比例，原点为画布中心）
    private func defaultAnchor(_ kind: ShareElementKind) -> CGPoint {
        switch kind {
        case .track:         return CGPoint(x: 0, y: -0.08)
        case .duration:      return CGPoint(x: -0.22, y: 0.28)
        case .pace:          return CGPoint(x: 0.22, y: 0.28)
        case .heartRate:     return CGPoint(x: -0.22, y: 0.40)
        case .elevationGain: return CGPoint(x: 0.22, y: 0.40)
        case .logo:          return CGPoint(x: 0, y: 0.46)
        }
    }

    private func toggle(_ kind: ShareElementKind) {
        var st = states[kind] ?? ShareElementState(enabled: false)
        st.enabled.toggle()
        states[kind] = st
        if st.enabled { selected = kind; updateTextColor(for: kind) } else if selected == kind { selected = nil }
    }

    // MARK: 背景模式 / 地图

    private func switchBackgroundMode(_ mode: ShareBackgroundMode) {
        guard mode != backgroundMode else { return }
        backgroundMode = mode
        switch mode {
        case .map:
            // 轨迹并入背景，关闭可叠加的轨迹元素
            if states[.track]?.enabled == true { states[.track]?.enabled = false }
            if selected == .track { selected = nil }
            // 已有快照则用当前轨迹色重绘（保持两种模式颜色一致）；否则重新生成
            if let snap = mapSnapshot {
                compositeTrack(on: snap)
            } else {
                generateMapBackground()
            }
        case .photo:
            // 回到照片模式自动恢复显示轨迹元素
            if states[.track] == nil {
                states[.track] = ShareElementState(enabled: true)
            } else {
                states[.track]?.enabled = true
            }
        }
        updateAllTextColors()       // 背景切换后按新背景重算文字色（地图生成完成会再算一次）
    }

    // 用 MKMapSnapshotter 渲染轨迹所在区域的地图，再把轨迹画上去作为背景
    private func generateMapBackground() {
        let coords = metrics.coordinates
        guard coords.count > 1 else { return }
        isGeneratingMap = true

        var rect = MKMapRect.null
        for c in coords {
            let p = MKMapPoint(c)
            rect = rect.union(MKMapRect(x: p.x, y: p.y, width: 0, height: 0))
        }
        let padX = rect.size.width * 0.2 + 1
        let padY = rect.size.height * 0.2 + 1
        rect = rect.insetBy(dx: -padX, dy: -padY)

        let snapScale: CGFloat = 2
        let options = MKMapSnapshotter.Options()
        options.mapRect = rect
        options.size = CGSize(width: exportWidth / snapScale, height: (exportWidth / aspect) / snapScale)  // 9:16
        options.scale = snapScale
        options.pointOfInterestFilter = .excludingAll
        options.traitCollection = UITraitCollection(userInterfaceStyle: mapDarkMode ? .dark : .light)

        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start(with: DispatchQueue.global(qos: .userInitiated)) { snapshot, _ in
            DispatchQueue.main.async {
                isGeneratingMap = false
                guard let snapshot else { return }
                mapSnapshot = snapshot
                compositeTrack(on: snapshot)
            }
        }
    }

    // 切换地图浅色/深色风格（外观烘焙在快照里，需重新生成）
    private func toggleMapStyle() {
        mapDarkMode.toggle()
        mapSnapshot = nil
        generateMapBackground()
    }

    // 在缓存的地图快照上绘制平滑轨迹（含深色描边底衬，提升任意颜色的可读性）
    private func compositeTrack(on snapshot: MKMapSnapshotter.Snapshot) {
        let base = snapshot.image
        let coords = metrics.coordinates
        let stroke = UIColor(trackColor)

        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = base.scale
        let renderer = UIGraphicsImageRenderer(size: base.size, format: format)

        mapImage = renderer.image { ctx in
            base.draw(at: .zero)
            guard coords.count > 1 else { return }
            let cg = ctx.cgContext
            let pts = coords.map { snapshot.point(for: $0) }
            let path = Self.smoothedCGPath(points: pts)
            cg.setLineJoin(.round)
            cg.setLineCap(.round)
            cg.addPath(path)
            cg.setStrokeColor(UIColor.black.withAlphaComponent(0.35).cgColor)
            cg.setLineWidth(13)
            cg.strokePath()
            cg.addPath(path)
            cg.setStrokeColor(stroke.cgColor)
            cg.setLineWidth(8)
            cg.strokePath()
        }
        updateAllTextColors()       // 地图背景就绪/变色后重算文字色
    }

    private static func smoothedCGPath(points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard points.count > 1 else { return path }
        guard points.count > 2 else {
            path.move(to: points[0]); path.addLine(to: points[1]); return path
        }
        path.move(to: points[0])
        for i in 0..<(points.count - 1) {
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(i + 2, points.count - 1)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        return path
    }

    // MARK: 文字色自适应（按所覆盖背景的平均色选黑/白）

    // 一次性精确更新（拖动结束 / 缩放 / 切背景 / 尺寸确定）
    private func updateTextColor(for kind: ShareElementKind) {
        guard kind != .track, let st = states[kind], let size = elementSizes[kind] else { return }
        let r = Self.sampleBackground(image: backgroundImage, canvasSize: canvasSizeState,
                                      offset: st.offset, elementSize: size, scale: st.scale)
        textColors[kind] = r.color
#if DEBUG
        recordDebug(kind, r.avg)
#endif
    }

    private func updateAllTextColors() {
        for kind in ShareElementKind.allCases where kind != .track {
            if states[kind]?.enabled == true { updateTextColor(for: kind) }
        }
    }

    // 拖动过程中的实时文字色：限频 + 后台采样，避免阻塞拖动主线程
    private func liveUpdateTextColor(for kind: ShareElementKind) {
        guard kind != .track, let st = states[kind], let size = elementSizes[kind] else { return }
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastLiveSampleTime >= liveSampleInterval else { return }
        lastLiveSampleTime = now
        let image = backgroundImage
        let canvas = canvasSizeState
        let offset = st.offset
        let scale = st.scale
        Self.sampleQueue.async {
            let r = Self.sampleBackground(image: image, canvasSize: canvas, offset: offset, elementSize: size, scale: scale)
            DispatchQueue.main.async {
                if textColors[kind] != r.color { textColors[kind] = r.color }
#if DEBUG
                recordDebug(kind, r.avg)
#endif
            }
        }
    }

#if DEBUG
    // 记录当前选中文字元素的采样调试信息
    private func recordDebug(_ kind: ShareElementKind, _ avg: UIColor) {
        guard kind == selected else { return }
        debugSampleColor = Color(uiColor: avg)
        let (rr, gg, bb) = avg.rgbComponents
        let wc = avg.contrastRatio(with: .white)
        let bc = avg.contrastRatio(with: .black)
        debugSampleText = String(format: "RGB %.2f/%.2f/%.2f  W:%.2f B:%.2f → %@",
                                 rr, gg, bb, wc, bc, wc >= 1.5 ? "WHITE" : "BLACK")
    }
#endif

    // 无背景图时为深色渐变背景 → 返回深色（结果取白字）
    private static let fallbackBgColor = UIColor(red: 0.1, green: 0.11, blue: 0.16, alpha: 1)
    private static let ciContext = CIContext(options: [.workingColorSpace: CGColorSpaceCreateDeviceRGB()])
    private static let sampleQueue = DispatchQueue(label: "com.sportsx.share.colorSample", qos: .userInitiated)

    // 纯函数：算元素覆盖区域平均色及对应黑/白文字色（可在后台线程调用，考虑 scaledToFill 裁切）
    private static func sampleBackground(image: UIImage?, canvasSize: CGSize, offset: CGSize, elementSize: CGSize, scale: CGFloat) -> (color: Color, avg: UIColor) {
        guard let image, canvasSize.width > 0, elementSize.width > 0 else {
            return (fallbackBgColor.adaptiveTextColor(), fallbackBgColor)
        }
        let cw = canvasSize.width, ch = canvasSize.height
        let halfW = elementSize.width * scale / 2
        let halfH = elementSize.height * scale / 2
        let cx0 = cw / 2 + offset.width - halfW
        let cy0 = ch / 2 + offset.height - halfH
        let cx1 = cw / 2 + offset.width + halfW
        let cy1 = ch / 2 + offset.height + halfH
        let iw = image.size.width, ih = image.size.height
        guard iw > 0, ih > 0 else { return (fallbackBgColor.adaptiveTextColor(), fallbackBgColor) }
        let fill = max(cw / iw, ch / ih)
        let dw = iw * fill, dh = ih * fill
        func c01(_ v: CGFloat) -> CGFloat { min(max(v, 0), 1) }
        let nx0 = c01((cx0 + (dw - cw) / 2) / dw)
        let nx1 = c01((cx1 + (dw - cw) / 2) / dw)
        let ny0 = c01((cy0 + (dh - ch) / 2) / dh)
        let ny1 = c01((cy1 + (dh - ch) / 2) / dh)
        guard nx1 > nx0, ny1 > ny0,
              let avg = averageColor(of: image, normalizedRect: CGRect(x: nx0, y: ny0, width: nx1 - nx0, height: ny1 - ny0)) else {
            return (fallbackBgColor.adaptiveTextColor(), fallbackBgColor)
        }
        return (avg.adaptiveTextColor(), avg)
    }

    private static func averageColor(of image: UIImage, normalizedRect: CGRect) -> UIColor? {
        guard let cg = image.cgImage else { return nil }
        let ci = CIImage(cgImage: cg)
        let ext = ci.extent
        // CIImage 原点在左下，归一化矩形用左上原点 → 翻转 y
        let rect = CGRect(
            x: ext.minX + normalizedRect.minX * ext.width,
            y: ext.minY + (1 - normalizedRect.maxY) * ext.height,
            width: normalizedRect.width * ext.width,
            height: normalizedRect.height * ext.height
        ).intersection(ext)
        guard !rect.isNull, rect.width >= 1, rect.height >= 1,
              let filter = CIFilter(name: "CIAreaAverage", parameters: [
                kCIInputImageKey: ci,
                kCIInputExtentKey: CIVector(cgRect: rect)
              ]),
              let output = filter.outputImage else { return nil }
        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(output, toBitmap: &bitmap, rowBytes: 4,
                         bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                         format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return UIColor(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255,
                       blue: CGFloat(bitmap[2]) / 255, alpha: 1)
    }

    @MainActor
    private func save() {
        let size = canvasSizeState
        guard size.width > 0 else { return }
        isSaving = true
        selected = nil

        let canvas = ShareExportCanvas(
            metrics: metrics,
            states: states,
            trackColor: trackColor,
            textColors: textColors,
            bgImage: backgroundImage,
            size: size
        )
        let scale = exportWidth / size.width
        guard let image = ImageTool.render(canvas, size: size, scale: scale) else {
            isSaving = false
            dismiss()
            ToastManager.shared.show(toast: Toast(message: "share.toast.failed"))
            return
        }
        ImageTool.saveToAlbum(image) { success in
            isSaving = false
            dismiss()
            ToastManager.shared.show(toast: Toast(message: success ? "share.toast.saved" : "share.toast.failed"))
        }
    }
}
