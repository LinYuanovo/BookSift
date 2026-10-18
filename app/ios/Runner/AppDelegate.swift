import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "booksift/update",
      binaryMessenger: engineBridge.pluginRegistry.registrar(forPlugin: "BooksiftUpdate")!.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "openFileLocation",
            let arguments = call.arguments as? [String: Any],
            let path = arguments["path"] as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      let url = URL(fileURLWithPath: path)
      let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
      picker.modalPresentationStyle = .formSheet
      self.window?.rootViewController?.present(picker, animated: true) {
        result(true)
      }
    }
  }
}
