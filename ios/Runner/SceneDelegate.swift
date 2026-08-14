import Flutter
import UIKit
import UserNotifications

/// Captures a cold-start push tap (app killed) before Flutter is alive and
/// stashes the destination URL where CurtainCue can consume it. The key must
/// stay in sync with CurtainCue._dartKey (`msq_curtain_cue`), including the
/// `flutter.` prefix that shared_preferences adds on iOS.
class SceneDelegate: FlutterSceneDelegate {
  static let cueKey = "flutter.msq_curtain_cue"

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard
      let response = connectionOptions.notificationResponse,
      let destination = Self.destination(
        inside: response.notification.request.content.userInfo
      )
    else { return }

    let defaults = UserDefaults.standard
    defaults.set(destination, forKey: Self.cueKey)
    defaults.synchronize()

    #if DEBUG
    NSLog("[MSQ.CUE] captured cold-start destination")
    #endif
  }

  private static func destination(inside payload: [AnyHashable: Any]) -> String? {
    let candidates = ["deep_link", "target", "url", "deeplink", "link"]

    func firstValue(in dictionary: [AnyHashable: Any]) -> String? {
      for candidate in candidates {
        guard let value = dictionary[candidate] as? String else { continue }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
      }
      return nil
    }

    if let direct = firstValue(in: payload) { return direct }
    for container in ["payload", "data"] {
      if let nested = payload[container] as? [AnyHashable: Any],
         let value = firstValue(in: nested) {
        return value
      }
    }
    return nil
  }
}
