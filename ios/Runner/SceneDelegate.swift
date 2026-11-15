import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
    override func sceneWillResignActive(_ scene: UIScene) {
        super.sceneWillResignActive(scene)
        window?.addSubview(visualEffectView)
    }

    override func sceneDidBecomeActive(_ scene: UIScene) {
        super.sceneDidBecomeActive(scene)
        visualEffectView.removeFromSuperview()
    }

    private lazy var visualEffectView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .light)
        let view = UIVisualEffectView(effect: blur)
        view.frame = UIScreen.main.bounds
        return view
    }()
}
