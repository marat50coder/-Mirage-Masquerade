import Flutter
import UIKit
import UserNotifications

/// Captures a cold-start push tap (app killed) before Flutter is alive and
/// stashes the destination URL where CurtainCue can consume it. The keys must
/// stay in sync with the Dart-side readers (`msq_curtain_cue`,
/// `msq_onelink_url`), including the `flutter.` prefix that shared_preferences
/// adds on iOS.
class SceneDelegate: FlutterSceneDelegate {
  static let cueKey = "flutter.msq_curtain_cue"
  static let oneLinkKey = "flutter.msq_onelink_url"

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    if let response = connectionOptions.notificationResponse,
       let destination = Self.destination(
        inside: response.notification.request.content.userInfo
       ) {
      let defaults = UserDefaults.standard
      defaults.set(destination, forKey: Self.cueKey)
      defaults.synchronize()

      #if DEBUG
      NSLog("[MSQ.CUE] captured cold-start destination")
      #endif
    }

    // Capture the OneLink Universal Link URL at cold start. AppsFlyer's SDK
    // collapses `pid` / `c` / `agency` into the OneLink brand slug for
    // re-targeting installs (match_type=id_matching), so the config-endpoint
    // body ships polluted `media_source` / `campaign` values and the
    // partner's Parameter-Passing diagnostic goes red. Stashing the raw URL
    // here lets TraceCourier restore the click parameters directly.
    for activity in connectionOptions.userActivities where
      activity.activityType == NSUserActivityTypeBrowsingWeb {
      if let url = activity.webpageURL {
        Self.stashOneLink(url)
      }
    }
  }

  override func scene(
    _ scene: UIScene,
    continue userActivity: NSUserActivity
  ) {
    super.scene(scene, continue: userActivity)
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let url = userActivity.webpageURL else { return }
    Self.stashOneLink(url)
  }

  private static func stashOneLink(_ url: URL) {
    let str = url.absoluteString
    guard !str.isEmpty else { return }
    let defaults = UserDefaults.standard
    defaults.set(str, forKey: Self.oneLinkKey)
    defaults.synchronize()

    #if DEBUG
    NSLog("[MSQ.ONELINK] captured %@", str)
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
