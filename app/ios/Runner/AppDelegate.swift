import Flutter
import Network
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let wifiPathMonitor = WifiPathMonitor()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let networkChannel = FlutterMethodChannel(
      name: "booksift/network",
      binaryMessenger: engineBridge.pluginRegistry.registrar(forPlugin: "BooksiftNetwork")!.messenger()
    )
    networkChannel.setMethodCallHandler { [wifiPathMonitor = self.wifiPathMonitor] call, result in
      guard call.method == "isWifi" else {
        result(FlutterMethodNotImplemented)
        return
      }
      wifiPathMonitor.isWifi { value in
        DispatchQueue.main.async { result(value) }
      }
    }
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

private final class WifiPathMonitor {
  private let monitor = NWPathMonitor()
  private let queue = DispatchQueue(label: "booksift.network-path")
  private var pathReady = false
  private var wifiAvailable = false
  private var pending: [(Bool) -> Void] = []

  init() {
    monitor.pathUpdateHandler = { [weak self] path in
      guard let self else { return }
      self.pathReady = true
      self.wifiAvailable = path.status == .satisfied && path.usesInterfaceType(.wifi)
      let callbacks = self.pending
      self.pending.removeAll()
      callbacks.forEach { $0(self.wifiAvailable) }
    }
    monitor.start(queue: queue)
  }

  func isWifi(_ completion: @escaping (Bool) -> Void) {
    queue.async {
      if self.pathReady {
        completion(self.wifiAvailable)
      } else {
        self.pending.append(completion)
      }
    }
  }
}
