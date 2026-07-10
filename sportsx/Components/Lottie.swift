//
//  Lottie.swift
//  sportsx
//
//  Created by 任杰 on 2026/7/9.
//


import SwiftUI
import Lottie

final class LottieContainerView: UIView {
    let animationView: LottieAnimationView

    init(animationView: LottieAnimationView) {
        self.animationView = animationView
        super.init(frame: .zero)

        clipsToBounds = true

        addSubview(animationView)

        animationView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: trailingAnchor),
            animationView.topAnchor.constraint(equalTo: topAnchor),
            animationView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        .zero
    }
}

struct LottieView: UIViewRepresentable {
    let animationName: String
    var loopMode: LottieLoopMode = .playOnce
    var contentMode: UIView.ContentMode = .scaleAspectFit
    var play: Bool = true
    var holdOnLastFrame: Bool = false
    var stopAtProgress: CGFloat? = nil
    
    func makeUIView(context: Context) -> LottieContainerView {
        guard let bundleURL = Bundle.main.url(
            forResource: "resources",
            withExtension: "bundle"
        ), let resourceBundle = Bundle(url: bundleURL) else {
            assertionFailure("resources.bundle not found")
            return LottieContainerView(animationView: LottieAnimationView())
        }
        
        guard let animationPath = resourceBundle.path(
            forResource: animationName,
            ofType: "json",
            inDirectory: "Lottie"
        ) else {
            assertionFailure("Lottie animation not found: \(animationName)")
            return LottieContainerView(animationView: LottieAnimationView())
        }
        
        guard let animation = LottieAnimation.filepath(animationPath) else {
            assertionFailure("Failed to load Lottie animation: \(animationPath)")
            return LottieContainerView(animationView: LottieAnimationView())
        }
        
        let animationView = LottieAnimationView(animation: animation)
        animationView.contentMode = contentMode
        animationView.loopMode = loopMode
        
        if play {
            let endProgress = stopAtProgress ?? 1.0

            if holdOnLastFrame {
                animationView.play(
                    fromProgress: 0,
                    toProgress: endProgress
                ) { finished in
                    guard finished else { return }

                    animationView.currentProgress = endProgress
                    animationView.pause()
                }
            } else if let stopAtProgress {
                animationView.play(
                    fromProgress: 0,
                    toProgress: stopAtProgress
                )
            } else {
                animationView.play()
            }
        }
        
        return LottieContainerView(animationView: animationView)
    }

    func updateUIView(_ container: LottieContainerView, context: Context) {
        let animationView = container.animationView
        animationView.loopMode = loopMode
        animationView.contentMode = contentMode

        if !play {
            animationView.pause()
        }
    }
}
