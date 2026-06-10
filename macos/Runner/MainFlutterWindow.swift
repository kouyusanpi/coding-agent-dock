import Cocoa
import FlutterMacOS
import UserNotifications

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    NotificationBridge.register(with: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

/// Posts macOS system notifications via UNUserNotificationCenter.
///
/// Authorization is requested lazily on the FIRST `show` call — never at app
/// startup — so the permission dialog cannot interfere with Patrol/XCUITest
/// activation (the reason the old NSUserNotificationCenter-based plugin was
/// removed; see CLAUDE.md).
enum NotificationBridge {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "agentdock/notifications", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "show":
        guard let args = call.arguments as? [String: Any],
              let title = args["title"] as? String,
              let body = args["body"] as? String else {
          result(FlutterError(
            code: "bad_args", message: "title/body required", details: nil))
          return
        }
        // Default: only notify while the app is in the background — when the
        // user is inside the app, the live status dots already tell the story.
        let onlyWhenInactive = args["onlyWhenInactive"] as? Bool ?? true
        if onlyWhenInactive && NSApp.isActive {
          result(false)
          return
        }
        show(title: title, body: body) { shown in result(shown) }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func show(
    title: String, body: String, completion: @escaping (Bool) -> Void
  ) {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
      guard granted else {
        DispatchQueue.main.async { completion(false) }
        return
      }
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = .default
      let request = UNNotificationRequest(
        identifier: UUID().uuidString, content: content, trigger: nil)
      center.add(request) { error in
        DispatchQueue.main.async { completion(error == nil) }
      }
    }
  }
}
