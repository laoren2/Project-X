//
//  ProgressBar.swift
//  sportsx
//
//  Created by 任杰 on 2026/3/8.
//

import SwiftUI


struct ProgressBar: View {
    var progress: Double
    var showsOutline: Bool = true

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.gray.opacity(0.25))
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .mask(
                    Rectangle()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .scaleEffect(x: progress, anchor: .leading)
                )
        }
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.35), lineWidth: 2)
                .opacity(showsOutline ? 1 : 0)
        )
    }
}

struct ProgressAnimationStep {
    let startProgress: Double
    let endProgress: Double
    let levelChange: Int
}

struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
}

struct XPProgressView: View {
    @State private var progress: Double
    @State private var level: Int
    @State private var steps: [ProgressAnimationStep] = []
    @State private var stepIndex: Int = 0
    @State private var animatedXP: Double
    @State private var iconScale: CGFloat = 1.0
    
    @State private var glowOpacity: Double = 0
    @State private var glowScale: CGFloat = 1.0
    @State private var particles: [Particle] = []
    
    let beforeXP: Int
    let deltaXP: Int
    
    var tier: Tier { return Tier(level: level) }
    
    init(beforeXP: Int, deltaXP: Int) {
        self.beforeXP = beforeXP
        self.deltaXP = deltaXP

        let xpPerLevel = 100
        let initialLevel = max(0, min(beforeXP / xpPerLevel + 1, 25))
        let initialProgress = (initialLevel == 25 ? 1.0 : Double(beforeXP % xpPerLevel) / Double(xpPerLevel))

        _level = State(initialValue: initialLevel)
        _progress = State(initialValue: initialProgress)
        _animatedXP = State(initialValue: Double(beforeXP))
    }
    
    var body: some View {
        HStack {
            ZStack {
                // Glow 背景
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.yellow.opacity(0.6),
                                Color.orange.opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
                    .scaleEffect(glowScale)
                    .opacity(glowOpacity)
                
                ForEach(particles) { p in
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: p.size, height: p.size)
                        .position(x: p.x, y: p.y)
                        .opacity(p.opacity)
                }
                
                Image("xp_logo_\(level)")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .scaleEffect(iconScale)
            }
            .frame(width: 60, height: 60)
            
            VStack {
                HStack {
                    Text(tier.baseKey) + Text(" ") + Text(tier.suffix)
                    Spacer()
                    Image("experience_points")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20)
                    Text(deltaXP > 0 ? "+\(deltaXP)" : "\(deltaXP)")
                        .foregroundStyle(Color.white)
                }
                ZStack {
                    ProgressBar(progress: progress)
                        .frame(height: 14)
                    Text("")
                        .modifier(AnimatedNumberText(value: animatedXP))
                }
            }
        }
        .padding(.vertical)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                startXPAnimation()
                
                // 数字动画：1s内从 beforeXP 到 beforeXP + deltaXP
                let target = Double(beforeXP + deltaXP)
                withAnimation(.timingCurve(0.2, 0.8, 0.2, 1.0, duration: 1.0)) {
                    animatedXP = target
                }
            }
        }
    }
    
    func startXPAnimation() {
        guard level > 0, level < 25 else { return }
        steps = buildSteps()
        stepIndex = 0
        playNextStep()
    }
    
    func playNextStep() {
        guard stepIndex < steps.count else { return }

        let step = steps[stepIndex]
        progress = step.startProgress
        withAnimation(.easeInOut(duration: 0.8)) {
            progress = step.endProgress
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            if step.levelChange > 0 {
                level += step.levelChange
                // 重置进度条
                if level < 25 {
                    progress = 0
                }
                // 图标动画
                withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                    iconScale = 1.3
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        iconScale = 1.0
                    }
                }
                // Glow 动画
                glowOpacity = 1
                glowScale = 0.8
                withAnimation(.easeOut(duration: 0.4)) {
                    glowScale = 1.6
                    glowOpacity = 0
                }
                // 粒子动画
                spawnParticles()
            }
            stepIndex += 1
            playNextStep()
        }
    }
    
    func buildSteps() -> [ProgressAnimationStep] {
        var steps: [ProgressAnimationStep] = []

        let xpPerLevel = 100
        var xp = beforeXP % xpPerLevel
        var gained = deltaXP
        var tempLevel = level

        while gained > 0 {
            if tempLevel == 25 { return steps }
            let remaining = xpPerLevel - xp
            if gained >= remaining {
                // 升级
                let start = Double(xp) / Double(xpPerLevel)
                steps.append(
                    ProgressAnimationStep(
                        startProgress: start,
                        endProgress: 1.0,
                        levelChange: 1
                    )
                )
                gained -= remaining
                xp = 0
                tempLevel += 1
            } else {
                // 最后一段
                let start = Double(xp) / Double(xpPerLevel)
                let end = Double(xp + gained) / Double(xpPerLevel)
                steps.append(
                    ProgressAnimationStep(
                        startProgress: start,
                        endProgress: end,
                        levelChange: 0
                    )
                )
                gained = 0
            }
        }
        return steps
    }
    
    func spawnParticles() {
        particles = (0..<30).map { _ in
            Particle(
                x: 30, // 图标中心
                y: 30,
                size: CGFloat.random(in: 2...5),
                opacity: 1
            )
        }
        for i in particles.indices {
            let dx = CGFloat.random(in: -50...50)
            let dy = CGFloat.random(in: -60...40)
            withAnimation(.easeOut(duration: 0.8)) {
                particles[i].x += dx
                particles[i].y += dy
                particles[i].opacity = 0
            }
        }
        // 清理
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            particles.removeAll()
        }
    }
}

struct AnimatedNumberText: AnimatableModifier {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    func body(content: Content) -> some View {
        Text("\(Int(value))")
            .font(.system(size: 15))
            .foregroundStyle(Color.secondText)
    }
}


struct TrainingStateProgressView: View {
    @State private var progress: Double
    @State private var animatedState: Double
    
    let beforeState: Int
    let deltaState: Int
    
    init(beforeState: Int, deltaState: Int) {
        self.beforeState = beforeState
        self.deltaState = deltaState

        let initialProgress = max(0.0, min(1.0, Double(beforeState) / 100))
        _progress = State(initialValue: initialProgress)
        _animatedState = State(initialValue: Double(beforeState))
    }
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "flame.fill")
                Text("training.sport_state")
                Spacer()
                Text(deltaState > 0 ? "+\(deltaState)" : "\(deltaState)")
            }
            .foregroundStyle(Color.white)
            ZStack {
                ProgressBar(progress: progress)
                    .frame(height: 14)
                Text("")
                    .modifier(AnimatedNumberText(value: animatedState))
            }
            HStack {
                Spacer()
                Text("training.sport_state.limit")
            }
            .foregroundStyle(Color.thirdText)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                startStateAnimation()
                let target = Double(beforeState + deltaState)
                withAnimation(.timingCurve(0.2, 0.8, 0.2, 1.0, duration: 1.0)) {
                    animatedState = target
                }
            }
        }
    }
    
    func startStateAnimation() {
        let endProgress = max(0.0, min(1.0, Double(beforeState + deltaState) / 100.0))
        withAnimation(.easeInOut(duration: 0.8)) {
            progress = endProgress
        }
    }
}
