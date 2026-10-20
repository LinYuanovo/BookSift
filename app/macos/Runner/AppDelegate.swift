import Cocoa
import FlutterMacOS
import Network

@main
class AppDelegate: FlutterAppDelegate {
  private let wifiPathMonitor = WifiPathMonitor()

  func registerNetworkChannel(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "booksift/network", binaryMessenger: messenger)
    channel.setMethodCallHandler { [wifiPathMonitor = self.wifiPathMonitor] call, result in
      guard call.method == "isWifi" else {
        result(FlutterMethodNotImplemented)
        return
      }
      wifiPathMonitor.isWifi { value in
        DispatchQueue.main.async { result(value) }
      }
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
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
