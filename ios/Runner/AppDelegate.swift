import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let shareChannel = FlutterMethodChannel(
      name: "policy_pal/share",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    shareChannel.setMethodCallHandler { call, result in
      guard call.method == "shareText" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let text = call.arguments as? String, !text.isEmpty else {
        result(FlutterError(code: "empty", message: "Nothing to share", details: nil))
        return
      }

      let presenter = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .filter { $0.activationState == .foregroundActive }
        .flatMap { $0.windows }
        .first(where: { $0.isKeyWindow })?.rootViewController
      guard var activeController = presenter else {
        result(FlutterError(code: "unavailable", message: "Sharing is unavailable", details: nil))
        return
      }
      while let presented = activeController.presentedViewController {
        activeController = presented
      }
      let sheet = UIActivityViewController(activityItems: [text], applicationActivities: nil)
      if let popover = sheet.popoverPresentationController {
        popover.sourceView = activeController.view
        popover.sourceRect = CGRect(
          x: activeController.view.bounds.midX,
          y: activeController.view.bounds.midY,
          width: 1,
          height: 1
        )
        popover.permittedArrowDirections = []
      }
      activeController.present(sheet, animated: true)
      result(nil)
    }
  }
}
