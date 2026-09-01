import UserNotifications

/// Pass-through NSE. Local notifications do not need mutation; kept so the
/// existing App Store extension target still archives.
final class NotificationService: UNNotificationServiceExtension {
  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    contentHandler(request.content)
  }
}
