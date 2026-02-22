import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let channelName = "com.example.happy_flutter/deep_links"
  private var deepLinkChannel: FlutterMethodChannel?
  private var initialDeepLink: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Set up the MethodChannel for deep links
    if let controller = window?.rootViewController as? FlutterViewController {
      deepLinkChannel = FlutterMethodChannel(
        name: channelName,
        binaryMessenger: controller.binaryMessenger
      )

      deepLinkChannel?.setMethodCallHandler { [weak self] call, result in
        if call.method == "getInitialDeepLink" {
          result(self?.initialDeepLink)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    // Check if the app was launched from a deep link
    if let url = launchOptions?[.url] as? URL {
      handleDeepLink(url: url)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    // Handle deep links when app is already running
    if handleDeepLink(url: url) {
      // Forward to Flutter via method channel
      deepLinkChannel?.invokeMethod("onDeepLink", arguments: url.absoluteString)
      return true
    }
    return super.application(app, open: url, options: options)
  }

  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    // Handle universal links
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL {
      if handleDeepLink(url: url) {
        deepLinkChannel?.invokeMethod("onDeepLink", arguments: url.absoluteString)
        return true
      }
    }
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }

  private func handleDeepLink(url: URL) -> Bool {
    // Only handle happy:// URLs
    if url.scheme == "happy" {
      initialDeepLink = url.absoluteString
      return true
    }
    return false
  }
}
