import Foundation
import Network

@MainActor
final class ConnectivityMonitor: ObservableObject {
    static let shared = ConnectivityMonitor()

    @Published private(set) var isOnline = true

    /// Fired once on each offline→online transition.
    var onReconnect: (@MainActor () -> Void)?

    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                let wasOffline = !self.isOnline
                self.isOnline = online
                if online && wasOffline {
                    self.onReconnect?()
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "connectivity-monitor", qos: .utility))
    }
}
