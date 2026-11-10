import Flutter
import UIKit
import receive_sharing_intent

final class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    if let url = connectionOptions.urlContexts.first?.url,
       SwiftReceiveSharingIntentPlugin.instance.hasMatchingSchemePrefix(url: url) {
      _ = SwiftReceiveSharingIntentPlugin.instance.application(
        UIApplication.shared,
        didFinishLaunchingWithOptions: [UIApplication.LaunchOptionsKey.url: url]
      )
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    for context in URLContexts {
      if SwiftReceiveSharingIntentPlugin.instance.application(
        UIApplication.shared,
        open: context.url,
        options: [:]
      ) {
        return
      }
    }
    super.scene(scene, openURLContexts: URLContexts)
  }
}
