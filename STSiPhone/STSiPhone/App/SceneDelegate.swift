import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // UIKit bridge if needed for future features
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            let repo = ProjectsRepositoryFactory.makeAppRepository()
            window.rootViewController = UIHostingController(rootView: ContentView(repo: repo))
            self.window = window
            window.makeKeyAndVisible()
        }
    }
}
