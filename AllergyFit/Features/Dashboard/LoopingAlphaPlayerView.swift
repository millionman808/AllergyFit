import SwiftUI
import AVFoundation

/// LoopingAlphaPlayerView
/// Hardware-accelerated transparent HEVC video player for Pip companion animations.
/// Seamlessly switches between idle, celebrate, eat, and drink video loops.
struct LoopingAlphaPlayerView: UIViewRepresentable {
    let videoName: String
    let isLooping: Bool
    var onFinished: (() -> Void)? = nil

    func makeUIView(context: Context) -> TransparentPlayerUIView {
        let view = TransparentPlayerUIView()
        view.play(videoName: videoName, isLooping: isLooping, onFinished: onFinished)
        return view
    }

    func updateUIView(_ uiView: TransparentPlayerUIView, context: Context) {
        uiView.play(videoName: videoName, isLooping: isLooping, onFinished: onFinished)
    }
}

final class TransparentPlayerUIView: UIView {
    private var queuePlayer: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?
    private var currentVideoName: String?
    private var currentIsLooping: Bool?
    private var endObserver: Any?
    private var onFinishedCallback: (() -> Void)?

    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }

    private func setupLayer() {
        backgroundColor = .clear
        isOpaque = false
        playerLayer.backgroundColor = UIColor.clear.cgColor
        playerLayer.videoGravity = .resizeAspect
    }

    func play(videoName: String, isLooping: Bool, onFinished: (() -> Void)?) {
        self.onFinishedCallback = onFinished
        if videoName == currentVideoName && isLooping == currentIsLooping {
            if !isLooping {
                queuePlayer?.seek(to: .zero)
                queuePlayer?.play()
            }
            return
        }
        self.currentVideoName = videoName
        self.currentIsLooping = isLooping

        // Clean up previous observers & players
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        playerLooper?.disableLooping()
        playerLooper = nil
        queuePlayer?.pause()
        queuePlayer?.removeAllItems()

        // Locate video in bundle or fallback to local path
        var videoURL = Bundle.main.url(forResource: videoName, withExtension: "mov")
        if videoURL == nil {
            let localPath = "/Users/elischafer/Developer/AllergyFit/AllergyFit/Resources/\(videoName).mov"
            if FileManager.default.fileExists(atPath: localPath) {
                videoURL = URL(fileURLWithPath: localPath)
            }
        }

        guard let url = videoURL else {
            print("[LoopingAlphaPlayerView] Video not found: \(videoName).mov")
            return
        }

        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)

        let player = AVQueuePlayer(playerItem: playerItem)
        player.isMuted = true
        player.automaticallyWaitsToMinimizeStalling = false
        playerLayer.player = player
        self.queuePlayer = player

        if isLooping {
            // Continuous seamless hardware looping
            self.playerLooper = AVPlayerLooper(player: player, templateItem: playerItem)
        } else {
            // One-shot playback (e.g. celebrate, eat, drink)
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { [weak self] _ in
                self?.onFinishedCallback?()
            }
        }

        player.play()
    }

    deinit {
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        playerLooper?.disableLooping()
        queuePlayer?.pause()
    }
}
